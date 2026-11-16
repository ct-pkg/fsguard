/*
 * R-03 判据 3 的负例夹具配套：`r03aux::AltWalk` 的 C 适配层。
 *
 * 只登记「这次遍历被调用过」，不做真实遍历；判据 3 只关心
 * 「同名 walk 的未限定调用歧义、限定调用可编译可运行」。
 */
#ifndef R03AUX_ALTWALK_SHIM_H
#define R03AUX_ALTWALK_SHIM_H

#include <stddef.h>

static inline int r03_alt_walk(const char *path, void *cb, void *ud, int depth)
{
    (void)cb;
    (void)ud;
    (void)depth;
    return path != NULL ? 0 : -1;
}

#endif
