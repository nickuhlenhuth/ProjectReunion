﻿// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root for license information.

#include "pch.h"

#include "MddDetourPackageGraph.h"

#include "PackageGraphManager.h"

#include <../Detours/detours.h>

// Windows provides HRESULT_FROM_WIN32() but not the reverse. We need that for compat reasons.
// Define WIN32_FROM_HRESULT() to covert an HRESULT to a Win32 Error Code if the HRESULT's facility
// is FACILITY_WIN32. See https://devblogs.microsoft.com/oldnewthing/20061103-07/?p=29133 for more details
#if !defined(WIN32_FROM_HRESULT)
inline DWORD Win32FromHResult(const HRESULT hr)
{
    if (HRESULT_FACILITY(hr) == FACILITY_WIN32)
    {
        return static_cast<DWORD>(HRESULT_CODE(hr));
    }
    else
    {
        return static_cast<DWORD>(hr);
    }
}
#define WIN32_FROM_HRESULT(hr) Win32FromHResult(hr)
#endif

static LONG (WINAPI * TrueGetCurrentPackageInfo)(
    const UINT32 flags,
    UINT32* bufferLength,
    BYTE* buffer,
    UINT32* count) = GetCurrentPackageInfo;

LONG DynamicGetCurrentPackageInfo(
    const UINT32 flags,
    UINT32* bufferLength,
    BYTE* buffer,
    UINT32* count);

static LONG (WINAPI * TrueGetCurrentPackageInfo2)(
    const UINT32 flags,
    PackagePathType packagePathType,
    UINT32* bufferLength,
    BYTE* buffer,
    UINT32* count) = GetCurrentPackageInfo2;

LONG DynamicGetCurrentPackageInfo2(
    const UINT32 flags,
    PackagePathType packagePathType,
    UINT32* bufferLength,
    BYTE* buffer,
    UINT32* count);

HRESULT MddDetourPackageGraphInitialize() noexcept
{
    // Do we need to detour package graph APIs?
    if (DetourIsHelperProcess())
    {
        return S_OK;
    }

    // Detour package graph APIs to our implementation
    FAIL_FAST_IF_WIN32_BOOL_FALSE(DetourRestoreAfterWith());
    FAIL_FAST_IF_WIN32_ERROR(DetourTransactionBegin());
    FAIL_FAST_IF_WIN32_ERROR(DetourUpdateThread(GetCurrentThread()));
    FAIL_FAST_IF_WIN32_ERROR(DetourAttach(&(PVOID&)TrueGetCurrentPackageInfo, DynamicGetCurrentPackageInfo));
    FAIL_FAST_IF_WIN32_ERROR(DetourTransactionCommit());
    return S_OK;
}

HRESULT _MddDetourPackageGraphShutdown() noexcept
{
    // Did we detour package graph APIs?
    if (DetourIsHelperProcess())
    {
        return S_OK;
    }

    // Stop Detour'ing package graph APIs to our implementation
    FAIL_FAST_IF_WIN32_ERROR(DetourTransactionBegin());
    FAIL_FAST_IF_WIN32_ERROR(DetourUpdateThread(GetCurrentThread()));
    FAIL_FAST_IF_WIN32_ERROR(DetourDetach(&(PVOID&)TrueGetCurrentPackageInfo, DynamicGetCurrentPackageInfo));
    FAIL_FAST_IF_WIN32_ERROR(DetourTransactionCommit());
    return S_OK;
}

void MddDetourPackageGraphShutdown() noexcept
{
    _MddDetourPackageGraphShutdown();
}

LONG DynamicGetCurrentPackageInfo(
    const UINT32 flags,
    UINT32* bufferLength,
    BYTE* buffer,
    UINT32* count)
{
    return DynamicGetCurrentPackageInfo2(flags, PackagePathType_Install, bufferLength, buffer, count);
}

LONG DynamicGetCurrentPackageInfo2(
    const UINT32 flags,
    PackagePathType packagePathType,
    UINT32* bufferLength,
    BYTE* buffer,
    UINT32* count)
{
    return WIN32_FROM_HRESULT(MddCore::PackageGraphManager::GetCurrentPackageInfo2(flags, packagePathType, bufferLength, buffer, count, TrueGetCurrentPackageInfo2));
}
