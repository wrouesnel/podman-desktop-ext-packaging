# Repackages the prebuilt Podman Desktop application (see scripts/build-app.sh).
# Build with: rpmbuild -bb --define "pkg_version ..." --define "pkg_release ..." --define "_sourcedir <dir of the artifact>"

%global appdir /opt/podman-desktop
%global app_id io.podman_desktop.PodmanDesktop

# prebuilt Electron application: no debuginfo, no stripping, no build-id links (would conflict with other Electron apps)
%global debug_package %{nil}
%global __os_install_post %{nil}
%global _build_id_links none

# the libraries bundled with Electron are provided by the application itself
%global __provides_exclude_from ^%{appdir}/.*$
%global __requires_exclude ^(libffmpeg|libEGL|libGLESv2|libvk_swiftshader|libvulkan)\\.so.*$
# the extensions and node modules resources embed binaries and scripts for other platforms / interpreters
%global __requires_exclude_from ^%{appdir}/resources/.*$

Name:           podman-desktop
Version:        %{pkg_version}
Release:        %{pkg_release}%{?dist}
Summary:        Manage Podman and other container engines from a single UI
License:        Apache-2.0
URL:            https://podman-desktop.io
Source0:        podman-desktop-app-%{app_version}-x86_64.tar.gz
ExclusiveArch:  x86_64

Requires:       hicolor-icon-theme
Requires:       xdg-utils
Recommends:     podman
Packager:       %{pkg_maintainer}

%description
Podman Desktop is an open source graphical tool enabling you to seamlessly work
with containers and Kubernetes from your local environment.

%prep
%setup -q -c -n %{name}-%{version}

%build
# prebuilt

%install
install -d %{buildroot}%{appdir} %{buildroot}%{_bindir}
cp -a podman-desktop/. %{buildroot}%{appdir}/
ln -s %{appdir}/podman-desktop %{buildroot}%{_bindir}/podman-desktop
cp -a share/. %{buildroot}%{_datadir}/
install -Dm 0644 BUILD_INFO %{buildroot}%{_docdir}/%{name}/BUILD_INFO

%files
%license podman-desktop/LICENSE.electron.txt
%doc %{_docdir}/%{name}/BUILD_INFO
%{appdir}
# setuid sandbox helper, used when unprivileged user namespaces are not available
%attr(4755, root, root) %{appdir}/chrome-sandbox
%{_bindir}/podman-desktop
%{_datadir}/applications/%{app_id}.desktop
%{_datadir}/metainfo/%{app_id}.metainfo.xml
%{_datadir}/icons/hicolor/scalable/apps/%{app_id}.svg
%{_datadir}/icons/hicolor/512x512/apps/%{app_id}.png

%changelog
* %(LC_ALL=C date -u +"%a %b %d %Y") %{pkg_maintainer} - %{pkg_version}-%{pkg_release}
- Automated build
