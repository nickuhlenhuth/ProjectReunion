// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root for license information.

#pragma once

#include "Microsoft.ApplicationModel.DynamicDependency.PackageDependencyContext.g.h"

#include <MsixDynamicDependency.h>

namespace winrt::Microsoft::ApplicationModel::DynamicDependency::implementation
{
    struct PackageDependencyContext : PackageDependencyContextT<PackageDependencyContext>
    {
        PackageDependencyContext() = default;

        PackageDependencyContext(MDD_PACKAGEDEPENDENCY_CONTEXT context);
        PackageDependencyContext(Microsoft::ApplicationModel::DynamicDependency::PackageDependencyContextId const& contextId);

        Microsoft::ApplicationModel::DynamicDependency::PackageDependencyContextId ContextId();
        hstring PackageFullName();
        void Remove();

    private:
        Microsoft::ApplicationModel::DynamicDependency::PackageDependencyContextId m_contextId;
    };
}
namespace winrt::Microsoft::ApplicationModel::DynamicDependency::factory_implementation
{
    struct PackageDependencyContext : PackageDependencyContextT<PackageDependencyContext, implementation::PackageDependencyContext>
    {
    };
}