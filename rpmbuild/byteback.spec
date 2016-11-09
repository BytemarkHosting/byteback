Name:           byteback
Version:        0.4.2
Release:        1%{?dist}
Summary:        Maintenance-free client & server backup scripts for Linux

Group:          Applications/System
License:        Ruby and GPLv2+ and ASL 2.0 and Artistic 2.0
URL:            https://github.com/BytemarkHosting/byteback
Source0:        byteback_%{version}.orig.tar.gz

BuildArch:      noarch
BuildRequires:  txt2man
Requires:       openssh-clients
Requires:       ruby
Requires:       rubygem-ffi
Requires:       rsync

%description
byteback encapsulates Bytemark's "best practice" for maintenance-free backups
with easy client and server setup.

"Maintenance-free" means that we'd rather make full use of a fixed amount of
disc space.  Management of disc space must be completely automatic, so the
process never grinds to a halt for reasons that could be automatically
resolved.  Failed backups can be restarted in case of network problems.

We use the standard OpenSSH on the server for encrypted transport & access
control, btrfs for simple snapshots and rsync for efficient data transfer
across the network.

Backups should require as little configuration as possible to be safe - just
the server address should be enough.


%prep
%setup -q -c
# No binary files, so should go in /usr/share.
sed -i -e 's|/usr/lib/byteback|/usr/share/byteback|g' bin/*
# Required to load system gems.
sed -i -e "2irequire 'rubygems'" bin/*


%build
make docs


%install
mkdir -p %{buildroot}%{_bindir}
cp -a bin/* %{buildroot}%{_bindir}/

mkdir -p %{buildroot}%{_datadir}/byteback
cp -a lib/* %{buildroot}%{_datadir}/byteback/

mkdir -p %{buildroot}%{_mandir}/man1
for i in man/*.man; do
    mv $i ${i%%.man}.1
done;
cp -a man/*.1 %{buildroot}%{_mandir}/man1/


%files
%doc README.md
%{_bindir}/*
%{_datadir}/byteback
%{_mandir}/man1/*.1*

