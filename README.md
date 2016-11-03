# Re-enable/check repositories tool
Re-Enable/check working PPAs after Ubuntu upgrade

## Re-enable Repositories version 3.1.0 (20161103)

### Install

```bash
sudo su -c '
	cp -fv ppa-reeanabler.sh /usr/local/bin/ppa-reeanabler
	cp -fv pkexec-ppa-reeanabler.sh /usr/local/bin/pkexec-ppa-reeanabler
	cp -fv org.freedesktop.pkexec.run-ppa-reeanabler-as-root.policy /usr/share/polkit-1/actions/
	desktop-file-install ppa-reeanabler.desktop
'

```

### Uninstall

```bash
sudo su -c '
	rm -fv /usr/local/bin/ppa-reeanabler
	rm -fv /usr/local/bin/pkexec-ppa-reeanabler
	rm -fv /usr/share/polkit-1/actions/org.freedesktop.pkexec.run-ppa-reeanabler-as-root.policy
	rm -fv /usr/share/applications/ppa-reeanabler.desktop
'

```

