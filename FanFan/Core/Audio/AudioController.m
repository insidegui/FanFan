//
//  AudioController.m
//  FanFan
//
//  Created by Guilherme Rambo on 26/03/21.
//

#import "AudioController.h"

#import <AudioToolbox/AudioServices.h>

@import os.log;

@interface AudioController ()
@property (strong) os_log_t log;
@end

@implementation AudioController

- (instancetype)init
{
    self = [super init];
    
    self.log = os_log_create("codes.rambo.FanFan", "AudioController");
    
    return self;
}

- (void)setSystemVolumeToValue:(float)volume
{
    AudioDeviceID device = [self _currentOutputDeviceID];
    if (device == kAudioDeviceUnknown) return;
    
    [self setOutputVolume:[NSNumber numberWithFloat:volume] onDevice:device];
}

- (AudioDeviceID)_currentOutputDeviceID
{
    AudioObjectPropertyAddress theAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    uint32 size = sizeof(AudioDeviceID);
    AudioDeviceID currentOutputDevice;

    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &size, &currentOutputDevice) != 0) {
        os_log_error(self.log, "Couldn't get current output device ID");
        return kAudioDeviceUnknown;
    }

    return currentOutputDevice;
}

- (void)setOutputVolume:(NSNumber *)volume onDevice:(AudioDeviceID)deviceID
{
    float v = volume.floatValue;

    os_log_debug(self.log, "%{public}@ %.2f", NSStringFromSelector(_cmd), v);

    BOOL shouldMute = v < 0.01;
    if (shouldMute) os_log_debug(self.log, "Volume is really low, will use mute property");

    AudioObjectPropertyAddress volumeAddress;
    volumeAddress.mElement = kAudioObjectPropertyElementMaster;
    volumeAddress.mScope = kAudioDevicePropertyScopeOutput;
    volumeAddress.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume;

    if (!AudioObjectHasProperty(deviceID, &volumeAddress)) {
        os_log_fault(self.log, "Device 0x%0x doesn't seem to have an output volume property we can set", deviceID);
        return;
    }

    Boolean isSettable;
    OSStatus error = AudioObjectIsPropertySettable(deviceID, &volumeAddress, &isSettable);
    if (error != noErr || !isSettable) {
        os_log_fault(self.log, "Device 0x%0x doesn't support setting the volume property", deviceID);
        return;
    }

    // We need to set the mute property accordingly because if the audio is currently
    // muted but we're trying to set the volume, it won't have any effect.

    AudioObjectPropertyAddress muteAddress;
    muteAddress.mElement = kAudioObjectPropertyElementMaster;
    muteAddress.mScope = kAudioDevicePropertyScopeOutput;
    muteAddress.mSelector = kAudioDevicePropertyMute;

    Boolean isMuteSettable;
    error = AudioObjectIsPropertySettable(deviceID, &muteAddress, &isMuteSettable);
    if (error == noErr && isMuteSettable) {
        int mute = (shouldMute) ? 1 : 0;
        error = AudioObjectSetPropertyData(deviceID, &muteAddress, 0, NULL, sizeof(mute), &mute);
        if (error != noErr) os_log_fault(self.log, "Unable to set mute property on device 0x%0x", deviceID);
    } else {
        os_log_fault(self.log, "Device 0x%0x doesn't support setting the mute property", deviceID);
    }

    error = AudioObjectSetPropertyData(deviceID, &volumeAddress, 0, NULL, sizeof(v), &v);
    if (error != noErr) {
        os_log_fault(self.log, "Failed to set output volume on device 0x%0x", deviceID);
        return;
    }
}

@end
