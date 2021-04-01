//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "AudioController.h"

@import Darwin.sys.sysctl;

int processIsTranslated() {
   int ret = 0;
   size_t size = sizeof(ret);
   if (sysctlbyname("sysctl.proc_translated", &ret, &size, NULL, 0) == -1)
   {
      if (errno == ENOENT)
         return 0;
      return -1;
   }
   return ret;
}
