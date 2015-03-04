dep 'provision' do
  requires 'local apt sources'.with('cn'),
           'linux modules',
           'vpn',
           'bastion'
end

LINUX_VERSION = `uname -r`.chomp
LINUX_IMAGE_PKG = "linux-image-#{LINUX_VERSION}"

dep 'linux modules' do
  requires 'initscripts.managed',
           "#{LINUX_IMAGE_PKG}.managed"
end

dep 'initscripts.managed' do
  # Workaround https://bugs.launchpad.net/bugs/1278437
  provides 'mountpoint'
end

dep "#{LINUX_IMAGE_PKG}.managed" do
  # CAN HAZ modprobe iptables
  provides []
end

dep 'local apt sources', :country do
  target = '/etc/apt/sources.list'
  template = dependency.load_path.parent / 'sources.list.erb'

  met? { Babushka::Renderable.new(target).from?(template) }
  meet {
    render_erb template, :to => target, :sudo => true
    Babushka::AptHelper.update_pkg_lists "Updating apt with #{country} mirrors"
  }
end

dep 'bastion' do
  requires dep('pptpd.managed'),
           'pptp.conf',
           'pptpd-options',
           'chap-secrets'

  requires 'sysctl.conf',
           'rc.local'
end

dep 'sysctl.conf' do
  target = '/etc/sysctl.conf'
  template = dependency.load_path.parent / 'sysctl.conf.erb'

  met? { Babushka::Renderable.new(target).from?(template) }
  meet {
    render_erb template, :to => target, :sudo => true
    sudo 'sysctl -p'
  }
end

dep 'rc.local' do
  target = '/etc/rc.local'
  template = dependency.load_path.parent / 'rc.local.erb'

  met? { Babushka::Renderable.new(target).from?(template) }
  meet {
    render_erb template, :to => target, :sudo => true
    sudo '/etc/rc.local'
  }
end

dep 'pptp.conf' do
  target = '/etc/pptp.conf'
  template = dependency.load_path.parent / 'pptp.conf.erb'

  met? { Babushka::Renderable.new(target).from?(template) }
  meet { render_erb template, :to => target, :sudo => true }
end

dep 'pptpd-options' do
  target = '/etc/ppp/pptpd-options'
  template = dependency.load_path.parent / 'pptp-options.erb'

  met? { Babushka::Renderable.new(target).from?(template) }
  meet {
    render_erb template, :to => target, :sudo => true
    sudo 'service pptpd restart'
  }
end

dep 'chap-secrets' do
  target = '/etc/ppp/chap-secrets'
  template = dependency.load_path.parent / 'chap-secrets.erb'

  # TODO: Fix permissions so non-root can compare, or switch to root to compare.
  meet { render_erb template, :to => target, :sudo => true }
end

dep 'vpn' do
  requires dep('default-jre.managed'),
           dep('icedtea-plugin.managed'),
           dep('firefox.managed'),
           dep('xterm.managed'),
           dep('matchbox-window-manager.managed'),
           dep('tightvncserver.managed'),
           'openjdk i386',
           'update-alternatives fix'
end

dep 'update-alternatives fix' do
  name = 'update-alternatives'
  bin = '/usr/bin' / name
  sbin = '/usr/sbin' / name

  met? { sbin.readlink == bin }
  meet { sudo "ln -s '#{bin}' '#{sbin}'" }
end

dep 'openjdk i386' do
  requires 'dpkg architecture'.with('i386')
  installs { via :apt, 'openjdk-7-jre:i386' }
  provides 'java'
end

dep 'dpkg architecture', :arch do
  met? { `dpkg --print-foreign-architectures`.include? arch }
  meet {
    sudo "dpkg --add-architecture #{arch}"
    Babushka::AptHelper.update_pkg_lists "Updating apt with #{arch} architecture"
  }
end
