/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/*
 * The destructors of `thread_local` objects, for the GCC (MinGW) build of the plugin.
 *
 * GCC emulates `thread_local` on MinGW (emutls), and both the emulated storage and the list of
 * `thread_local` destructors (libstdc++'s __cxa_thread_atexit) are freed by winpthreads key
 * destructors when a thread exits. winpthreads runs them in the order the keys were made, and the
 * emutls key is made first: the storage is freed, then the destructors run on it. Qt keeps objects
 * with destructors in `thread_local`s since 6.8.2 (QUnifiedTimer, the JIT stack of
 * QRegularExpression), so the render thread and the interface thread crash when they end, at
 * every exit of the player (VLC issue 29082; MinGW bugs 527 and 727, GCC PR 80816).
 *
 * This definition replaces libstdc++'s (the plugin links libstdc++ statically, so the archive's
 * one is not pulled in): the destructors of a thread are kept in a fiber local storage slot,
 * whose callback runs when the thread ends, before the DLL_THREAD_DETACH notifications that run
 * the winpthreads key destructors. The emulated storage is still there then.
 */
#if defined(_WIN32) && defined(__GNUC__) && !defined(__clang__)

#include <windows.h>

#include <cstdlib>

namespace
{

struct ThreadDtor
{
    void (*dtor)(void*);
    void* object;
    ThreadDtor* next;
};

// Runs the destructors of the thread that ends, the last registered first (as the standard asks).
void NTAPI runThreadDtors(void* head)
{
    ThreadDtor* entry = static_cast<ThreadDtor*>(head);
    while (entry)
    {
        ThreadDtor* next = entry->next;
        entry->dtor(entry->object);
        std::free(entry);
        entry = next;
    }
}

DWORD dtorSlot()
{
    // made once, for every thread (a function-local static is thread safe with GCC)
    static const DWORD slot = FlsAlloc(runThreadDtors);
    return slot;
}

} // namespace

extern "C" int __cxa_thread_atexit(void (*dtor)(void*), void* object, void* /* dsoHandle */)
{
    const DWORD slot = dtorSlot();
    if (slot == FLS_OUT_OF_INDEXES)
        return -1;

    ThreadDtor* entry = static_cast<ThreadDtor*>(std::malloc(sizeof(ThreadDtor)));
    if (!entry)
        return -1;
    entry->dtor = dtor;
    entry->object = object;
    entry->next = static_cast<ThreadDtor*>(FlsGetValue(slot));
    if (!FlsSetValue(slot, entry))
    {
        std::free(entry);
        return -1;
    }
    return 0;
}

#endif
