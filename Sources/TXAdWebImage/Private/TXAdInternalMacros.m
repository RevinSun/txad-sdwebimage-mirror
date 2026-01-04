/*
 * This file is part of the TXAdWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAdInternalMacros.h"

os_log_t txad_getDefaultLog(void) {
    static dispatch_once_t onceToken;
    static os_log_t log;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.hackemist.TXAdWebImage", "Default");
    });
    return log;
}

void txad_executeCleanupBlock (__strong txad_cleanupBlock_t *block) {
    (*block)();
}
