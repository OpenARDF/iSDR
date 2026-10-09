/*
 *  dspThread.cpp
 *  iSDR
 *
 *  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
 */

#import "dspThread.h"
#import <Foundation/NSAutoreleasePool.h>

dspThread::dspThread() :
mThread(),
mBufferManager(NULL),
mRunLoop(NULL),
mThreadDone(true),
mEnableDSP(false),
mThreadCreated(false),
mStartupComplete(false),
mStartupSucceeded(false)
{
	pthread_mutex_init(&mStateMutex, NULL);
	pthread_cond_init(&mStateCondition, NULL);
}

dspThread::~dspThread()
{
	killThread();
	pthread_cond_destroy(&mStateCondition);
	pthread_mutex_destroy(&mStateMutex);
}

void dspThread::RunLoopSourcePerformRoutine(void *info)
{
	// Signaling the source is only a wake-up mechanism; processing occurs below.
	(void)info;
}

void* dspThread::PosixThreadMainRoutine(void* data)
{
	dspThread *worker = static_cast<dspThread *>(data);
	worker->run();
	return NULL;
}

void dspThread::run()
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	CFRunLoopSourceContext context = {0, this, NULL, NULL, NULL, NULL, NULL, NULL, NULL, RunLoopSourcePerformRoutine};
	CFRunLoopSourceRef runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
	CFRunLoopRef runLoop = CFRunLoopGetCurrent();

	if(runLoopSource != NULL)
	{
		CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
		mBufferManager->RegisterSource(runLoop, runLoopSource);
		mBufferManager->AudioBufferFlush();
		mBufferManager->setDSPBufferReady(TRUE);
	}

	pthread_mutex_lock(&mStateMutex);
	mRunLoop = runLoop;
	mStartupSucceeded = (runLoopSource != NULL);
	mStartupComplete = true;
	pthread_cond_broadcast(&mStateCondition);
	pthread_mutex_unlock(&mStateMutex);

	while(runLoopSource != NULL && !mThreadDone.load(std::memory_order_acquire))
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, true);
		if(mEnableDSP.load(std::memory_order_acquire))
		{
			uint16_t remainingPasses = 10;
			while(mBufferManager->ProcessAudio() && remainingPasses-- > 0)
			{
			}
		}
	}

	if(runLoopSource != NULL)
	{
		mBufferManager->UnRegisterSource();
		mBufferManager->setDSPBufferReady(FALSE);
		CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
		CFRelease(runLoopSource);
	}

	pthread_mutex_lock(&mStateMutex);
	mRunLoop = NULL;
	pthread_mutex_unlock(&mStateMutex);

	[pool release];
}

int dspThread::LaunchDSPThread(FFTBufferManager* bufferManager)
{
	if(bufferManager == NULL || !bufferManager->isValid())
		return 1;

	pthread_mutex_lock(&mStateMutex);
	if(mThreadCreated)
	{
		pthread_mutex_unlock(&mStateMutex);
		return 1;
	}

	mBufferManager = bufferManager;
	mThreadDone.store(false, std::memory_order_release);
	mEnableDSP.store(false, std::memory_order_release);
	mStartupComplete = false;
	mStartupSucceeded = false;

	const int threadError = pthread_create(&mThread, NULL, PosixThreadMainRoutine, this);
	if(threadError != 0)
	{
		mBufferManager = NULL;
		mThreadDone.store(true, std::memory_order_release);
		pthread_mutex_unlock(&mStateMutex);
		return threadError;
	}

	mThreadCreated = true;
	while(!mStartupComplete)
		pthread_cond_wait(&mStateCondition, &mStateMutex);
	const bool startupSucceeded = mStartupSucceeded;
	pthread_mutex_unlock(&mStateMutex);

	if(!startupSucceeded)
	{
		pthread_join(mThread, NULL);
		pthread_mutex_lock(&mStateMutex);
		mThreadCreated = false;
		mBufferManager = NULL;
		pthread_mutex_unlock(&mStateMutex);
		return 1;
	}

	return 0;
}

void dspThread::killThread()
{
	pthread_mutex_lock(&mStateMutex);
	if(!mThreadCreated)
	{
		pthread_mutex_unlock(&mStateMutex);
		return;
	}

	mEnableDSP.store(false, std::memory_order_release);
	mThreadDone.store(true, std::memory_order_release);
	if(mRunLoop != NULL)
	{
		CFRunLoopStop(mRunLoop);
		CFRunLoopWakeUp(mRunLoop);
	}
	pthread_mutex_unlock(&mStateMutex);

	// The thread is joinable so the buffer manager remains alive through cleanup.
	pthread_join(mThread, NULL);

	pthread_mutex_lock(&mStateMutex);
	mThreadCreated = false;
	mBufferManager = NULL;
	pthread_mutex_unlock(&mStateMutex);
}

void dspThread::dspEnable()
{
	mEnableDSP.store(true, std::memory_order_release);
}

void dspThread::dspDisable()
{
	mEnableDSP.store(false, std::memory_order_release);
}

BOOL dspThread::threadState()
{
	return mEnableDSP.load(std::memory_order_acquire) ? TRUE : FALSE;
}
