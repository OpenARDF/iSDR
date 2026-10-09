/*
 *  dspThread.h
 *  iSDR
 *

 This software is provided by OpenARDF on an "AS IS" basis.
 OPENARDF MAKES NO WARRANTIES, EXPRESS OR IMPLIED,
 INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE
 SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL OPENARDF BE LIABLE FOR ANY SPECIAL,
 INDIRECT, INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE OPENARDF SOFTWARE,
 HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF OPENARDF HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.

 *
 */
#ifndef __DSPTHREAD_H__
#define __DSPTHREAD_H__

#import <assert.h>
#import <pthread.h>
#import <stdio.h>
#import <sys/types.h>
#import <CoreFoundation/CFRunLoop.h>
#import <objc/objc.h>

#include <atomic>

#import "FFTBufferManager.h"

class dspThread
{
public:
	dspThread();
	~dspThread();

	int  LaunchDSPThread(FFTBufferManager* BufferManager);
	void killThread();
	void dspEnable();
	void dspDisable();
	BOOL threadState();

private:
	static void* PosixThreadMainRoutine(void* data);
	static void RunLoopSourcePerformRoutine(void *info);
	void run();

	pthread_t			mThread;
	pthread_mutex_t		mStateMutex;
	pthread_cond_t		mStateCondition;
	FFTBufferManager*	mBufferManager;
	CFRunLoopRef			mRunLoop;
	std::atomic<bool>	mThreadDone;
	std::atomic<bool>	mEnableDSP;
	bool					mThreadCreated;
	bool					mStartupComplete;
	bool					mStartupSucceeded;
};

#endif
