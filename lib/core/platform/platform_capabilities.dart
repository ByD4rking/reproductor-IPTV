enum ClientProfile { mobile, tablet, tv, desktop, web }

class PlatformCapabilities {
  const PlatformCapabilities({required this.profile, this.hls=true, this.dash=false, this.pip=false, this.hardwareDecode=true, this.remoteControl=false});
  final ClientProfile profile;
  final bool hls;
  final bool dash;
  final bool pip;
  final bool hardwareDecode;
  final bool remoteControl;
}
