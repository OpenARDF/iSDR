//
//  FileHandler.m
//  iSDR
//
//  Copyright (c) 2011-2026 OpenARDF. Licensed under the MIT License.
//

#import "FileHandler.h"
#import "MultichannelMixerController.h"

@implementation FileHandler

@synthesize soundBuffer0ptr;
@synthesize soundBuffer1ptr;
@synthesize bufferFlags;
@synthesize _SoundBuffer0, _SoundBuffer1;
@synthesize channelsInFile;
@synthesize fileStats;

static AudioBufferList bufList[2];

static SInt32 ISDRScaleAudioSample(SInt32 sample, SInt16 scale)
{
	if(scale > 0)
	{
		const unsigned int shift = (unsigned int)MIN(scale, 31);
		const SInt64 scaled = (SInt64)sample * ((SInt64)1 << shift);
		return (SInt32)MAX((SInt64)INT32_MIN, MIN((SInt64)INT32_MAX, scaled));
	}
	if(scale < 0)
	{
		const unsigned int shift = (unsigned int)MIN(-(SInt32)scale, 31);
		return (SInt32)((SInt64)sample / ((SInt64)1 << shift));
	}
	return sample;
}

static SInt32 ISDRSampleMagnitude(SInt32 sample)
{
	return sample == INT32_MIN ? INT32_MAX : (SInt32)labs(sample);
}

- (id)initFH
{
	soundBuffer0ptr = &_SoundBuffer0;
	soundBuffer1ptr = &_SoundBuffer1;
	_SoundBuffer0.data = nil;
	_SoundBuffer1.data = nil;
	_Xafref = nil;
	fillPeriodicTimer = nil;
	fillOnceTimer = nil;
	timerInterval = (float)MAX_AUDIOBUFFERSIZE_FRAMES/(10. * kGraphSampleRate);
	self.fileStats = [FileStats new];
	fileStats.framesRead = 0.;
	fileStats.frameRate = kGraphSampleRate;
	fileStats.frameRateScaleFactor = 1.0;
	fileStats.fileLengthInFrames = 0.;
	fileStats.amplitudeScaleFactor = INITIAL_SCALE_FACTOR;
	fileStats.channelsInFile = 0;
	_currentFileURL = nil;
	return self;
}

// ARC: things that need to be called before FileHandler gets dealloc'd to ensure nothing gets leaked
- (void)dealloc
{
    SDR_DEBUGPRINT(("FileHandler dealloc\n"));

    if(_SoundBuffer0.data) free(_SoundBuffer0.data);
	_SoundBuffer0.data = nil;
	soundBuffer0ptr = nil;

    if(_SoundBuffer1.data) free(_SoundBuffer1.data);
	_SoundBuffer1.data = nil;
	soundBuffer1ptr = nil;

	if(_Xafref != nil)
	{
		[self fillBuffTimer:CancelTimer selector:nil];
		ExtAudioFileDispose(_Xafref);
		_Xafref = nil;
	}

	if(fillPeriodicTimer)
	{
		[fillPeriodicTimer invalidate];
		fillPeriodicTimer = nil;
	}

	if(fillOnceTimer)
	{
		[fillOnceTimer invalidate];
		fillOnceTimer = nil;
	}

}


//- (BOOL)getSoundBuffers:(SoundBuffer *)soundBuffer0 buff1:(SoundBuffer *)soundBuffer1
//{
//	soundBuffer0 = &_SoundBuffer0;
//	soundBuffer1 = &_SoundBuffer1;
//
//	return FALSE;
//}


- (void)pauseFileReads
{
	if(_Xafref != nil)
	{
		[self fillBuffTimer:CancelTimer selector:nil];
	}
	return;
}


- (void)resumeFileReads
{
	if(_Xafref != nil)
	{
		[self fillBuffTimer:StartTimer selector:nil];
		[self fillBuffTimer:FireTimer selector:nil];
	}
	return;
}


- (void)fillFileBuffers
{
	if(_isRunning) return;
	[self loadBuffers];
	return;
//	[self fillBuffOnceTimer:StartTimer];
}


- (BOOL)isRunning
{
	return _isRunning;
}


- (NSURL *)getCurrentFileURL
{
	return _currentFileURL;
}

- (void)fillBuffOnceTimer:(TTimerCommand)command
{
	if(_isRunning) return; // don't fill if periodic fills are occurring

	switch(command)
	{
		case CancelTimer:
			if(fillOnceTimer)
			{
				[fillOnceTimer invalidate];
				fillOnceTimer = nil;
			}
			break;

		case StartTimer:
			if(fillOnceTimer)
			{
				[fillOnceTimer fire];
				SDR_DEBUGPRINT(("Buffer fills not keeping up!\n"));
			}
			fillOnceTimer = [NSTimer scheduledTimerWithTimeInterval:FILLDELAY target:self selector:@selector(loadBuffers) userInfo:nil repeats:NO];
			break;

		case FireTimer:
			if(fillOnceTimer)
			{
				[fillOnceTimer fire];
			}
			break;

		default:
			SDR_DEBUGPRINT(("Illegal command sent to setFoxTimer!\n"));
			break;
	}

	return;
}


- (void)fillBuffTimer:(TTimerCommand)command selector:(SEL)aSelector
{
	if(aSelector == nil) aSelector = @selector(loadBuffers);

	switch(command)
	{
		case CancelTimer:
			if(fillPeriodicTimer)
			{
				[fillPeriodicTimer invalidate];
				fillPeriodicTimer = nil;
			}
			_isRunning = FALSE;
			break;

		case StartTimer:
			if(fillPeriodicTimer)
			{
				[fillPeriodicTimer invalidate];
			}
			fillPeriodicTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:aSelector userInfo:nil repeats:YES];
			_isRunning = TRUE;
			break;

		case FireTimer:
			if(fillPeriodicTimer)
			{
				[fillPeriodicTimer fire];
			}
			break;

		default:
			SDR_DEBUGPRINT(("Illegal command sent to setFoxTimer!\n"));
			break;
	}

	return;
}


- (BOOL)loadBuffers
{
//	SDR_DEBUGPRINT(("loadBuffers: playing for %4.2f sec.\n", elapsedPlayingTime));

	if(_Xafref == nil) return kAudioFileNotOpenError;

	OSStatus result;

	if(__atomic_load_n(bufferFlags, __ATOMIC_ACQUIRE) & AUDIOBUFFER0)
	{
		_SoundBuffer0.numFrames = MAX_AUDIOBUFFERSIZE_FRAMES;
		UInt32 samples = MAX_AUDIOBUFFERSIZE_FRAMES * _SoundBuffer0.asbd.mChannelsPerFrame;

#ifdef __IPHONE_8_0
		bufList[0].mBuffers[0].mDataByteSize = samples * sizeof(AUDIO_UNIT_SAMPLE_TYPE);
#else
		bufList[0].mBuffers[0].mDataByteSize = samples * sizeof(AudioUnitSampleType);
#endif

		// perform a synchronous sequential read of the audio data out of the file into our allocated data buffer
		result = ExtAudioFileRead(_Xafref, &(_SoundBuffer0.numFrames), &bufList[0]);

		if(result)
		{
			SDR_DEBUGPRINT(("ExtAudioFileRead result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			if(_SoundBuffer0.data != nil)
			{
				free(_SoundBuffer0.data);
				_SoundBuffer0.data = nil;
			}

			if(_SoundBuffer1.data != nil)
			{
				free(_SoundBuffer1.data);
				_SoundBuffer1.data = nil;
			}

			// close the file and dispose the ExtAudioFileRef
			ExtAudioFileDispose(_Xafref);
			_Xafref = nil;

#ifdef SDR_DEBUG
			[self printExtAudioFileError:result];
#endif
			return result;
		}
		else
		{
			if(_SoundBuffer0.numFrames == 0) //EOF
			{
				SDR_DEBUGPRINT(("Buff0 at EOF (%u) - wrapping to start\n", (unsigned int)_SoundBuffer0.numFrames));
				ExtAudioFileSeek (_Xafref, 0);

				_SoundBuffer0.numFrames = MAX_AUDIOBUFFERSIZE_FRAMES;
				UInt32 samples = MAX_AUDIOBUFFERSIZE_FRAMES * _SoundBuffer0.asbd.mChannelsPerFrame;

#ifdef __IPHONE_8_0
				bufList[0].mBuffers[0].mDataByteSize = samples * sizeof(AUDIO_UNIT_SAMPLE_TYPE);
#else
				bufList[0].mBuffers[0].mDataByteSize = samples * sizeof(AudioUnitSampleType);
#endif

				result = ExtAudioFileRead(_Xafref, &(_SoundBuffer0.numFrames), &bufList[0]);
				fileStats.framesRead = 0;

				if(result)
				{
					SDR_DEBUGPRINT(("ExtAudioFileRead result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
					if(_SoundBuffer0.data != nil)
					{
						free(_SoundBuffer0.data);
						_SoundBuffer0.data = nil;
					}

					if(_SoundBuffer1.data != nil)
					{
						free(_SoundBuffer1.data);
						_SoundBuffer1.data = nil;
					}

					// close the file and dispose the ExtAudioFileRef
					ExtAudioFileDispose(_Xafref);
					_Xafref = nil;

#ifdef SDR_DEBUG
					[self printExtAudioFileError:result];
#endif
					return result;
				}
			}

			fileStats.framesRead += _SoundBuffer0.numFrames;

			SDR_DEBUGPRINT(("Packets read into buffer0 = %u\n\n", (unsigned int)_SoundBuffer0.numFrames));
			__atomic_fetch_and(bufferFlags, ~AUDIOBUFFER0, __ATOMIC_RELEASE);
		}

		//	AudioUnitSampleType *in = mSoundBuffer.data;
		SInt32 maxData=0;

		if(fileStats.amplitudeScaleFactor > 0)
		{
			for(UInt32 i=0, j=0; i<_SoundBuffer0.numFrames; i++)
			{
				_SoundBuffer0.data[j] = ISDRScaleAudioSample(_SoundBuffer0.data[j], fileStats.amplitudeScaleFactor);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer0.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer0.data[j]);
				j++;
				_SoundBuffer0.data[j] = ISDRScaleAudioSample(_SoundBuffer0.data[j], fileStats.amplitudeScaleFactor);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer0.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer0.data[j]);
				j++;
			}
		}
		else
		{
			SInt16 shift = -fileStats.amplitudeScaleFactor;
			for(UInt32 i=0, j=0; i<_SoundBuffer0.numFrames; i++)
			{
				_SoundBuffer0.data[j] = ISDRScaleAudioSample(_SoundBuffer0.data[j], -shift);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer0.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer0.data[j]);
				j++;
				_SoundBuffer0.data[j] = ISDRScaleAudioSample(_SoundBuffer0.data[j], -shift);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer0.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer0.data[j]);
				j++;
			}
		}

		if(maxData > MAX_AUDIO_AMPLITUDE) fileStats.amplitudeScaleFactor--;
		if(maxData < MIN_AUDIO_AMPLITUDE) fileStats.amplitudeScaleFactor++;
		SDR_DEBUGPRINT(("Max amp = %d scaling: %d\n", (int)maxData, fileStats.amplitudeScaleFactor));
	}

	if(__atomic_load_n(bufferFlags, __ATOMIC_ACQUIRE) & AUDIOBUFFER1)
	{
		_SoundBuffer1.numFrames = MAX_AUDIOBUFFERSIZE_FRAMES;
		UInt32 samples = MAX_AUDIOBUFFERSIZE_FRAMES * _SoundBuffer1.asbd.mChannelsPerFrame;

#ifdef __IPHONE_8_0
		bufList[1].mBuffers[0].mDataByteSize = samples * sizeof(AUDIO_UNIT_SAMPLE_TYPE);
#else
		bufList[1].mBuffers[0].mDataByteSize = samples * sizeof(AudioUnitSampleType);
#endif

		result = ExtAudioFileRead(_Xafref, &(_SoundBuffer1.numFrames), &bufList[1]);

		if(result)
		{
			SDR_DEBUGPRINT(("ExtAudioFileRead result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			if(_SoundBuffer0.data != nil)
			{
				free(_SoundBuffer0.data);
				_SoundBuffer0.data = nil;
			}

			if(_SoundBuffer1.data != nil)
			{
				free(_SoundBuffer1.data);
				_SoundBuffer1.data = nil;
			}

			// close the file and dispose the ExtAudioFileRef
			ExtAudioFileDispose(_Xafref);
			_Xafref = nil;

#ifdef SDR_DEBUG
			[self printExtAudioFileError:result];
#endif
			return result;
		}
		else
		{
			if(_SoundBuffer1.numFrames == 0)
			{
				SDR_DEBUGPRINT(("Buff1 at EOF (%u) - wrapping to start\n", (unsigned int)_SoundBuffer1.numFrames));
				ExtAudioFileSeek (_Xafref, 0);

				_SoundBuffer1.numFrames = MAX_AUDIOBUFFERSIZE_FRAMES;
				UInt32 samples = MAX_AUDIOBUFFERSIZE_FRAMES * _SoundBuffer1.asbd.mChannelsPerFrame;

#ifdef __IPHONE_8_0
				bufList[1].mBuffers[0].mDataByteSize = samples * sizeof(AUDIO_UNIT_SAMPLE_TYPE);
#else
				bufList[1].mBuffers[0].mDataByteSize = samples * sizeof(AudioUnitSampleType);
#endif

				result = ExtAudioFileRead(_Xafref, &(_SoundBuffer1.numFrames), &bufList[1]);
				fileStats.framesRead = 0;

				if(result)
				{
					SDR_DEBUGPRINT(("ExtAudioFileRead result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
					if(_SoundBuffer0.data != nil)
					{
						free(_SoundBuffer0.data);
						_SoundBuffer0.data = nil;
					}

					if(_SoundBuffer1.data != nil)
					{
						free(_SoundBuffer1.data);
						_SoundBuffer1.data = nil;
					}

					// close the file and dispose the ExtAudioFileRef
					ExtAudioFileDispose(_Xafref);
					_Xafref	= nil;

#ifdef SDR_DEBUG
					[self printExtAudioFileError:result];
#endif
					return result;
				}
			}

			fileStats.framesRead += _SoundBuffer0.numFrames;

			SDR_DEBUGPRINT(("Packets read into buffer1 = %u\n", (unsigned int)_SoundBuffer1.numFrames));
			__atomic_fetch_and(bufferFlags, ~AUDIOBUFFER1, __ATOMIC_RELEASE);
		}

		SInt32 maxData=0;

		if(fileStats.amplitudeScaleFactor > 0)
		{
			for(UInt32 i=0, j=0; i<_SoundBuffer1.numFrames; i++)
			{
				_SoundBuffer1.data[j] = ISDRScaleAudioSample(_SoundBuffer1.data[j], fileStats.amplitudeScaleFactor);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer1.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer1.data[j]);
				j++;
				_SoundBuffer1.data[j] = ISDRScaleAudioSample(_SoundBuffer1.data[j], fileStats.amplitudeScaleFactor);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer1.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer1.data[j]);
				j++;
			}
		}
		else
		{
			SInt16 shift = -fileStats.amplitudeScaleFactor;
			for(UInt32 i=0, j=0; i<_SoundBuffer1.numFrames; i++)
			{
				_SoundBuffer1.data[j] = ISDRScaleAudioSample(_SoundBuffer1.data[j], -shift);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer1.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer1.data[j]);
				j++;
				_SoundBuffer1.data[j] = ISDRScaleAudioSample(_SoundBuffer1.data[j], -shift);
				if(maxData < ISDRSampleMagnitude(_SoundBuffer1.data[j])) maxData = ISDRSampleMagnitude(_SoundBuffer1.data[j]);
				j++;
			}
		}

		if(maxData > MAX_AUDIO_AMPLITUDE) fileStats.amplitudeScaleFactor--;
		if(maxData < MIN_AUDIO_AMPLITUDE) fileStats.amplitudeScaleFactor++;
		SDR_DEBUGPRINT(("Max amp = %d scaling: %d\n", (int)maxData, fileStats.amplitudeScaleFactor));
	}

	return FALSE;
}

// load audio data from the demo files into mSoundBuffer.data used in the render proc
- (OSStatus)loadFile:(NSURL *)sourceURL
{
	BOOL holdIsRunning = _isRunning;
	CFURLRef cfSourceURL = (__bridge CFURLRef)sourceURL;

	[self fillBuffTimer:CancelTimer selector:nil];
	_isRunning = holdIsRunning;

	__atomic_store_n(bufferFlags, AUDIOBUFFER0 | AUDIOBUFFER1, __ATOMIC_RELEASE);
	fileStats.amplitudeScaleFactor = INITIAL_SCALE_FACTOR;

	if(cfSourceURL == nil)
	{
		SDR_DEBUGPRINT(("loadFile: sourceURL cannot be nil!\n"));
		return kAudioFileNotOpenError;
	}

	if(_Xafref != nil)
	{
		ExtAudioFileDispose(_Xafref);
		_Xafref = nil;
	}

	// open the source file
	OSStatus result = ExtAudioFileOpenURL(cfSourceURL, &_Xafref);

	if(result)
	{
#ifdef SDR_DEBUG
		[self printExtAudioFileError:result];
#endif
		return result;
	}

	if(!_Xafref)
	{
		SDR_DEBUGPRINT(("ExtAudioFileOpenURL result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
		return kAudioFileNotOpenError;
	}
	else
	{
		SDR_DEBUGPRINT(("Opened file successfully\n"));
	}

	// get the file data format, this represents the file's actual data format
//	CAStreamBasicDescription clientFormat;
	UInt32 propSize = sizeof(clientFormat);

	result = ExtAudioFileGetProperty(_Xafref, kExtAudioFileProperty_FileDataFormat, &propSize, &clientFormat);

	if(result)
	{
		SDR_DEBUGPRINT(("ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));

		// close the file and dispose the ExtAudioFileRef
		ExtAudioFileDispose(_Xafref);
		_Xafref = nil;

#ifdef SDR_DEBUG
		[self printExtAudioFileError:result];
#endif
		return result;
	}

	SDR_DEBUGPRINT(("File format:\n"));
	clientFormat.Print();
	fileFormat = clientFormat;
	channelsInFile = clientFormat.NumberChannels();

	// set the client format to be what we want back
//	double rateRatio = kGraphSampleRate / clientFormat.mSampleRate;
	clientFormat.mSampleRate = kGraphSampleRate;
	clientFormat.SetAUCanonical(2, TRUE);

	propSize = sizeof(clientFormat);
	result = ExtAudioFileSetProperty(_Xafref, kExtAudioFileProperty_ClientDataFormat, propSize, &clientFormat);

	if(result)
	{
		// close the file and dispose the ExtAudioFileRef
		ExtAudioFileDispose(_Xafref);
		_Xafref = nil;

		SDR_DEBUGPRINT(("ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
#ifdef SDR_DEBUG
		[self printExtAudioFileError:result];
#endif
		return result;
	}

	SDR_DEBUGPRINT(("Buffer format:\n"));
	clientFormat.Print();

	// get the file's length in sample frames
	UInt64 numFrames = 0;
	propSize = sizeof(numFrames);
	result = ExtAudioFileGetProperty(_Xafref, kExtAudioFileProperty_FileLengthFrames, &propSize, &numFrames);

	if(result)
	{
	// close the file and dispose the ExtAudioFileRef
		ExtAudioFileDispose(_Xafref);
		_Xafref = nil;

		SDR_DEBUGPRINT(("ExtAudioFileGetProperty kExtAudioFileProperty_FileLengthFrames result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
#ifdef SDR_DEBUG
		[self printExtAudioFileError:result];
#endif
		return result;
	}

	fileStats.fileLengthInFrames = numFrames;
	fileStats.frameRateScaleFactor = fileStats.frameRate / fileFormat.mSampleRate;
	fileStats.filePlayTime = 0.5 + (numFrames / fileFormat.mSampleRate);
	SDR_DEBUGPRINT(("Play time = %4.2f seconds\n", fileStats.filePlayTime));

	//	numFrames = (UInt32)(numFrames * rateRatio); // account for any sample rate conversion

	// set up our buffer
	_SoundBuffer0.numFrames = MAX_AUDIOBUFFERSIZE_FRAMES;
	_SoundBuffer0.asbd = clientFormat;
	_SoundBuffer1.numFrames = MAX_AUDIOBUFFERSIZE_FRAMES;
	_SoundBuffer1.asbd = clientFormat;

	if(_SoundBuffer0.data != nil)
	{
		free(_SoundBuffer0.data);
		soundBuffer0ptr = nil;
	}

	if(_SoundBuffer1.data != nil)
	{
		free(_SoundBuffer1.data);
		soundBuffer1ptr = nil;
	}

	UInt32 samples = MAX_AUDIOBUFFERSIZE_FRAMES * _SoundBuffer0.asbd.mChannelsPerFrame;

#ifdef __IPHONE_8_0
	_SoundBuffer0.data = (AUDIO_UNIT_SAMPLE_TYPE *)calloc(samples, sizeof(AUDIO_UNIT_SAMPLE_TYPE));
	_SoundBuffer0.sampleNum = 0;

	_SoundBuffer1.data = (AUDIO_UNIT_SAMPLE_TYPE *)calloc(samples, sizeof(AUDIO_UNIT_SAMPLE_TYPE));
	_SoundBuffer1.sampleNum = 0;

	// set up a AudioBufferList to read data into
	bufList[0].mNumberBuffers = 1;
	bufList[0].mBuffers[0].mNumberChannels = 2;
	bufList[0].mBuffers[0].mData = _SoundBuffer0.data;
	bufList[0].mBuffers[0].mDataByteSize = samples * sizeof(AUDIO_UNIT_SAMPLE_TYPE);

	bufList[1].mNumberBuffers = 1;
	bufList[1].mBuffers[0].mNumberChannels = 2;
	bufList[1].mBuffers[0].mData = _SoundBuffer1.data;
	bufList[1].mBuffers[0].mDataByteSize = samples * sizeof(AUDIO_UNIT_SAMPLE_TYPE);
#else
	_SoundBuffer0.data = (AudioUnitSampleType *)calloc(samples, sizeof(AudioUnitSampleType));
	_SoundBuffer0.sampleNum = 0;

	_SoundBuffer1.data = (AudioUnitSampleType *)calloc(samples, sizeof(AudioUnitSampleType));
	_SoundBuffer1.sampleNum = 0;

	// set up a AudioBufferList to read data into
	bufList[0].mNumberBuffers = 1;
	bufList[0].mBuffers[0].mNumberChannels = 2;
	bufList[0].mBuffers[0].mData = _SoundBuffer0.data;
	bufList[0].mBuffers[0].mDataByteSize = samples * sizeof(AudioUnitSampleType);

	bufList[1].mNumberBuffers = 1;
	bufList[1].mBuffers[0].mNumberChannels = 2;
	bufList[1].mBuffers[0].mData = _SoundBuffer1.data;
	bufList[1].mBuffers[0].mDataByteSize = samples * sizeof(AudioUnitSampleType);
#endif

	SInt64 fileLocation;
	result = ExtAudioFileTell(_Xafref, &fileLocation);

	if(result)
	{
		SDR_DEBUGPRINT(("FileHandler: 1. Error reading file location!\n"));
	}

	SDR_DEBUGPRINT(("File location should be zero to start = %lld\n", fileLocation));

	// perform a synchronous sequential read of the audio data out of the file into our allocated data buffer
	result = ExtAudioFileRead(_Xafref, &(_SoundBuffer0.numFrames), &bufList[0]);

	if(result)
	{
		SDR_DEBUGPRINT(("ExtAudioFileRead result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
		if(_SoundBuffer0.data != nil)
		{
			free(_SoundBuffer0.data);
			_SoundBuffer0.data = nil;
		}

		if(_SoundBuffer1.data != nil)
		{
			free(_SoundBuffer1.data);
			_SoundBuffer1.data = nil;
		}

		// close the file and dispose the ExtAudioFileRef
		ExtAudioFileDispose(_Xafref);
		_Xafref = nil;

#ifdef SDR_DEBUG
		[self printExtAudioFileError:result];
#endif
		return result;
	}
	else
	{
		SDR_DEBUGPRINT(("Packets read into buffer0 = %u\n", (unsigned int)_SoundBuffer0.numFrames));
		__atomic_fetch_and(bufferFlags, ~AUDIOBUFFER0, __ATOMIC_RELEASE);
	}

	result = ExtAudioFileTell(_Xafref, &fileLocation);

	if(result)
	{
		SDR_DEBUGPRINT(("FileHandler: 2. Error reading file location!\n"));
	}

	SDR_DEBUGPRINT(("File location = %lld\n", fileLocation));


	result = ExtAudioFileRead(_Xafref, &(_SoundBuffer1.numFrames), &bufList[1]);

	if(result)
	{
		SDR_DEBUGPRINT(("ExtAudioFileRead result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
		if(_SoundBuffer0.data != nil)
		{
			free(_SoundBuffer0.data);
			_SoundBuffer0.data = nil;
		}

		if(_SoundBuffer1.data != nil)
		{
			free(_SoundBuffer1.data);
			_SoundBuffer1.data = nil;
		}

		// close the file and dispose the ExtAudioFileRef
		ExtAudioFileDispose(_Xafref);
		_Xafref = nil;

#ifdef SDR_DEBUG
		[self printExtAudioFileError:result];
#endif
		return result;
	}
	else
	{
		SDR_DEBUGPRINT(("Packets read into buffer1 = %u\n", (unsigned int)_SoundBuffer1.numFrames));
		__atomic_fetch_and(bufferFlags, ~AUDIOBUFFER1, __ATOMIC_RELEASE);
	}

	result = ExtAudioFileTell(_Xafref, &fileLocation);

	if(result)
	{
		SDR_DEBUGPRINT(("FileHandler: 3.Error reading file location!\n"));
	}

	SDR_DEBUGPRINT(("File location = %lld\n", fileLocation));

	// Force load buffers to initialize scale factor
	__atomic_fetch_or(bufferFlags, AUDIOBUFFER0 | AUDIOBUFFER1, __ATOMIC_RELEASE);
	[self loadBuffers];
	ExtAudioFileSeek (_Xafref, 0);
	[self loadBuffers];

	fileStats.framesRead = 0.;
	if(holdIsRunning) [self resumeFileReads];

	_currentFileURL = sourceURL;

	fileStats.centerFrequency = -FLT_MAX;

	NSString *URLString = [[sourceURL path] lastPathComponent];
	NSRange freqStart = [URLString rangeOfString:@"_+"];
	NSRange freqEnd = [URLString rangeOfString:@"+_" options:NSBackwardsSearch];

	try {
		// remove any trailing text (e.g., "kHz") from the frequency string
		if(freqEnd.location != NSNotFound)
		{
			freqEnd.length = freqEnd.location;
			freqEnd.location = 0;
			freqEnd = [URLString rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet] options:NSBackwardsSearch range:freqEnd];
			//		SDR_DEBUGPRINT(("freqEnd.length = %d  .location = %d\n", freqEnd.length, freqEnd.location));
			freqEnd.location += 1;
		}

		if((freqStart.location != NSNotFound) && (freqEnd.location != NSNotFound))
		{
			freqStart.location += 2;
			freqStart.length = (freqEnd.location - freqStart.location);

			//		SDR_DEBUGPRINT(("freqStart.length = %d  .location = %d\n", freqStart.length, freqStart.location));

			if((freqStart.length > 0) && (freqStart.length < 12))
			{
				float frequency = 0.;
				NSUInteger holdLength = freqStart.length;
				NSString* freqString = [URLString substringWithRange:freqStart];
				NSRange underScoreRange = [freqString rangeOfString:@"_" options:NSBackwardsSearch];

				SDR_DEBUGPRINT(("Frequency string to parse: %s\n", [freqString UTF8String]));

				int len = (int)freqStart.length;
				while(len)
				{
					freqStart = [freqString rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
					if(freqStart.location != NSNotFound)
					{
						frequency *= 10.;
						frequency += [[freqString substringWithRange:freqStart] floatValue];
						freqStart.location++;
						len -= freqStart.location;
						freqStart.length = len;
						freqString = [freqString substringWithRange:freqStart];
					}
					else
					{
						len = 0;
					}
				}

				// If no "_" is found in the frequency string, and the string is
				// shorter than 7 characters, then assume the frequency is
				// provided in kHz. Otherwise, assume the frequency is in Hz.
				if(underScoreRange.location != NSNotFound)
				{
					// Here we should use the location of the "_" to determine
					// where the decimal point is located. e.g., 123_4 => 123.4 Hz

					NSUInteger decimalPlaces = holdLength - underScoreRange.location - 1;

					//				if(decimalPlaces < 4)
					//				{
					frequency /= (powf(10.,decimalPlaces));
					//				}
				}

				if((frequency < MAX_CENTER_FREQUENCY) && (frequency > MIN_CENTER_FREQUENCY))
				{
					fileStats.centerFrequency = frequency;
				}


				//decimalDigitCharacterSet
				//Pull out every character that is a member of the above character set.
				//Arrange those characters into a string that is then converted to a float.
				SDR_DEBUGPRINT(("Frequency found in file name: %4.3f kHz\n", fileStats.centerFrequency));
			}
			else
			{
				SDR_DEBUGPRINT(("Frequency location not found in file name: %s\n", [URLString UTF8String]));
			}
		}
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred when parsing file name!\n");
	}



	NSString* nameString = [[sourceURL path] lastPathComponent];
	NSInteger maxLength = 40;

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		maxLength = 80;
	}

	if([nameString length] > maxLength)
	{
		NSString* extensionString = [nameString pathExtension];
		freqStart.location = 0;
		freqStart.length = maxLength-5;
		nameString = [[nameString substringWithRange:freqStart] stringByAppendingString:@"..."];
		if([extensionString length] > 0)
		{
			nameString = [nameString stringByAppendingString:@"]."];
			nameString = [nameString stringByAppendingString:extensionString];
		}
	}

	fileStats.fileName = [[NSString alloc] initWithString:nameString];

	SDR_DEBUGPRINT(("*fileName: %s\n", [fileStats.fileName UTF8String]));

	return noErr;
}


#ifdef SDR_DEBUG
- (void)printExtAudioFileError:(OSStatus)result
{
	switch(result)
	{
		case kExtAudioFileError_CodecUnavailableInputConsumed:
			SDR_DEBUGPRINT(("Ext file error: The ExtAudioFileWrite function was interrupted and the last buffer that you provided was successfully written to disk.\n"));
			break;

		case kExtAudioFileError_CodecUnavailableInputNotConsumed:
			SDR_DEBUGPRINT(("Ext file error: The ExtAudioFileWrite function was interrupted and the last buffer that you provided was not successfully written to disk.\n"));
			break;

		case kExtAudioFileError_InvalidProperty:
			SDR_DEBUGPRINT(("Ext file error: Invalid property!\n"));
			break;

		case kExtAudioFileError_InvalidPropertySize:
			SDR_DEBUGPRINT(("Ext file error: Invalid property size!\n"));
			break;

		case kExtAudioFileError_NonPCMClientFormat:
			SDR_DEBUGPRINT(("Ext file error: Non-PCM client format!\n"));
			break;

		case kExtAudioFileError_InvalidChannelMap:
			SDR_DEBUGPRINT(("Ext file error: The number of channels does not match the specified format.\n"));
			break;

		case kExtAudioFileError_InvalidOperationOrder:
			SDR_DEBUGPRINT(("Ext file error: Invalid operation order!\n"));
			break;

		case kExtAudioFileError_InvalidDataFormat:
			SDR_DEBUGPRINT(("Ext file error: Invalid data format!\n"));
			break;

		case kExtAudioFileError_MaxPacketSizeUnknown:
			SDR_DEBUGPRINT(("Ext file error: Max packet size unknown!\n"));
			break;

		case kExtAudioFileError_InvalidSeek:
			SDR_DEBUGPRINT(("Ext file error: An attempt to write, or an offset, is out of bounds.\n"));
			break;

		case kExtAudioFileError_AsyncWriteTooLarge:
			SDR_DEBUGPRINT(("Ext file error: Async write too large!\n"));
			break;

		case kExtAudioFileError_AsyncWriteBufferOverflow:
			SDR_DEBUGPRINT(("Ext file error: Async write buffer overflow!\n"));
			break;

			// general file error codes
		case kAudioFileNotOpenError:
			SDR_DEBUGPRINT(("Ext file error: File not open!\n"));
			break;

		case kAudioFileEndOfFileError:
			SDR_DEBUGPRINT(("Ext file error: End of File!\n"));
			break;

		case kAudioFilePositionError:
			SDR_DEBUGPRINT(("Ext file error: File position error!\n"));
			break;

		case kAudioFileFileNotFoundError:
			SDR_DEBUGPRINT(("Ext file error: File not found!\n"));
			break;

		default:
			SDR_DEBUGPRINT(("Ext file error: Unknown error occurred! %d\n", (int)result));
			break;
	}

	return;
}
#endif


@end


@implementation FileStats
@synthesize fileLengthInFrames;
@synthesize framesRead;
@synthesize frameRate;
@synthesize frameRateScaleFactor;
@synthesize filePlayTime;
@synthesize centerFrequency;
@synthesize amplitudeScaleFactor;
@synthesize channelsInFile;
@synthesize fileName;

@end
