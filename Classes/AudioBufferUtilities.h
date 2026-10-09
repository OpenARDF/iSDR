/*
 Copyright (c) 2026 OpenARDF. Licensed under the MIT License.
*/

/*
 * Platform-neutral buffer primitives shared by the real-time audio path and
 * host-side tests. These helpers never allocate or lock.
 */

#ifndef __AUDIO_BUFFER_UTILITIES_H__
#define __AUDIO_BUFFER_UTILITIES_H__

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

static inline bool ISDRCopyFramesIntoRing(int32_t *ring,
										 size_t capacityFrames,
										 size_t startFrame,
										 const int32_t *source,
										 size_t frameCount)
{
	if (ring == NULL || source == NULL || capacityFrames == 0 ||
		startFrame >= capacityFrames || frameCount > capacityFrames)
		return false;

	const size_t firstCount = frameCount < (capacityFrames - startFrame)
		? frameCount : (capacityFrames - startFrame);
	memcpy(ring + startFrame, source, firstCount * sizeof(int32_t));
	memcpy(ring, source + firstCount, (frameCount - firstCount) * sizeof(int32_t));
	return true;
}

static inline bool ISDRCopyFramesFromRing(const int32_t *ring,
										 size_t capacityFrames,
										 size_t startFrame,
										 int32_t *destination,
										 size_t frameCount)
{
	if (ring == NULL || destination == NULL || capacityFrames == 0 ||
		startFrame >= capacityFrames || frameCount > capacityFrames)
		return false;

	const size_t firstCount = frameCount < (capacityFrames - startFrame)
		? frameCount : (capacityFrames - startFrame);
	memcpy(destination, ring + startFrame, firstCount * sizeof(int32_t));
	memcpy(destination + firstCount, ring, (frameCount - firstCount) * sizeof(int32_t));
	return true;
}

typedef struct ISDRStereoFileCursor
{
	size_t activeBuffer;
	size_t framePositions[2];
} ISDRStereoFileCursor;

/*
 * Copy interleaved stereo input into non-interleaved output. A render can
 * cross from one file buffer into the other; each exhausted buffer is reported
 * exactly once so the asynchronous reader can refill it.
 */
static inline size_t ISDRCopyStereoFileFrames(const int32_t *buffers[2],
											 const size_t frameCounts[2],
											 ISDRStereoFileCursor *cursor,
											 int32_t *leftOutput,
											 int32_t *rightOutput,
											 size_t requestedFrames,
											 uint32_t *exhaustedMask)
{
	if (buffers == NULL || frameCounts == NULL || cursor == NULL ||
		leftOutput == NULL || rightOutput == NULL || exhaustedMask == NULL)
		return 0;

	size_t copiedFrames = 0;
	uint32_t exhausted = 0;

	while (copiedFrames < requestedFrames)
	{
		const size_t index = cursor->activeBuffer & 1U;
		const uint32_t bufferBit = UINT32_C(1) << index;
		if ((exhausted & bufferBit) != 0)
			break;

		const size_t position = cursor->framePositions[index];
		if (buffers[index] == NULL || position >= frameCounts[index])
		{
			exhausted |= bufferBit;
			cursor->framePositions[index] = 0;
			cursor->activeBuffer = index ^ 1U;
			continue;
		}

		const size_t availableFrames = frameCounts[index] - position;
		const size_t remainingFrames = requestedFrames - copiedFrames;
		const size_t copyCount = availableFrames < remainingFrames
			? availableFrames : remainingFrames;
		const int32_t *input = buffers[index] + (position * 2U);

		for (size_t frame = 0; frame < copyCount; frame++)
		{
			leftOutput[copiedFrames + frame] = input[frame * 2U];
			rightOutput[copiedFrames + frame] = input[frame * 2U + 1U];
		}

		copiedFrames += copyCount;
		cursor->framePositions[index] += copyCount;
		if (cursor->framePositions[index] == frameCounts[index])
		{
			exhausted |= bufferBit;
			cursor->framePositions[index] = 0;
			cursor->activeBuffer = index ^ 1U;
		}
	}

	*exhaustedMask = exhausted;
	return copiedFrames;
}

#endif
