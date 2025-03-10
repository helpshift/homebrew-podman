class Podman < Formula
  desc "Tool for managing OCI containers and pods"
  homepage "https://podman.io/"
  url "https://github.com/containers/podman/archive/v4.8.0.tar.gz"
  sha256 "cd0afd1fb493b0c099fd8634525f318f35e4e84c1d7735d8426a722a4d5c8409"
  license all_of: ["Apache-2.0", "GPL-3.0-or-later"]
  revision 1
  head "https://github.com/containers/podman.git", branch: "main"
  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "5a67c98e2547d8c51442080f3512dc9f60812fd7568eadbffd43b0b48e91e49d"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "d6b400d9346fa1c5618f49f1b84596375fba70f34387fb17e8234c907d13a4e7"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "5cea80226ddda734c5d1280c07479579fabd858dd82569394b5b271778b9f59f"
    sha256 cellar: :any_skip_relocation, sonoma:         "ab31cf27bae3c73533f9bc6564bd76860dbf5ead263e9248ce56fece3a98edca"
    sha256 cellar: :any_skip_relocation, ventura:        "87295162ba4f7363940a74d445792b79f72ecb3738f4ee18854eed71f15676d3"
    sha256 cellar: :any_skip_relocation, monterey:       "662045c6c29eadf23b25be4e436b90c5f8865ba906799de14dea031181d5ef45"
    sha256                               x86_64_linux:   "0897c304b04fa54b422f0da105dc3ad4c1683a45afb10327467f8f6fd3cc90e3"
  end
  depends_on "go" => :build
  depends_on "go-md2man" => :build
  uses_from_macos "python" => :build
  on_macos do
    depends_on "make" => :build
    depends_on "helpshift/homebrew-dependencies/qemu"
  end
  on_linux do
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
    depends_on "pkg-config" => :build
    depends_on "protobuf" => :build
    depends_on "rust" => :build
    depends_on "conmon"
    depends_on "crun"
    depends_on "fuse-overlayfs"
    depends_on "gpgme"
    depends_on "libseccomp"
    depends_on "slirp4netns"
    depends_on "systemd"
  end
  resource "gvproxy" do
    on_macos do
      url "https://github.com/containers/gvisor-tap-vsock/archive/refs/tags/v0.7.3.tar.gz"
      sha256 "851ed29b92e15094d8eba91492b6d7bab74aff4538dae0c973eb7d8ff48afd8a"
    end
  end

  resource "vfkit" do
    on_macos do
      url "https://github.com/crc-org/vfkit/archive/refs/tags/v0.5.0.tar.gz"
      sha256 "abfc3ca8010aca5bd7cc658680ffaae0a80ba1a180a2b37f9a7c4fce14b8957f"
    end
  end
  resource "catatonit" do
    on_linux do
      url "https://github.com/openSUSE/catatonit/archive/refs/tags/v0.2.0.tar.gz"
      sha256 "d0cf1feffdc89c9fb52af20fc10127887a408bbd99e0424558d182b310a3dc92"
    end
  end
  resource "netavark" do
    on_linux do
      url "https://github.com/containers/netavark/archive/refs/tags/v1.9.0.tar.gz"
      sha256 "9ec50b715ded0a0699134c001656fdd1411e3fb5325d347695c6cb8cc5fcf572"
    end
  end
  resource "aardvark-dns" do
    on_linux do
      url "https://github.com/containers/aardvark-dns/archive/refs/tags/v1.9.0.tar.gz"
      sha256 "d6b51743d334c42ec98ff229be044b5b2a5fedf8da45a005447809c4c1e9beea"
    end
  end
  def install
    if OS.mac?
      ENV["CGO_ENABLED"] = "1"
      system "gmake", "podman-remote"
      bin.install "bin/darwin/podman" => "podman-remote"
      bin.install_symlink bin/"podman-remote" => "podman"
      system "gmake", "podman-mac-helper"
      bin.install "bin/darwin/podman-mac-helper" => "podman-mac-helper"
      resource("gvproxy").stage do
        system "gmake", "gvproxy"
        (libexec/"podman").install "bin/gvproxy"
      end
      resource("vfkit").stage do
        ENV["CGO_ENABLED"] = "1"
        ENV["CGO_CFLAGS"] = "-mmacosx-version-min=11.0"
        ENV["GOOS"]="darwin"
        arch = Hardware::CPU.intel? ? "amd64" : Hardware::CPU.arch.to_s
        system "gmake", "out/vfkit-#{arch}"
        (libexec/"podman").install "out/vfkit-#{arch}" => "vfkit"
      end
      system "gmake", "podman-remote-darwin-docs"
      man1.install Dir["docs/build/remote/darwin/*.1"]
      bash_completion.install "completions/bash/podman"
      zsh_completion.install "completions/zsh/_podman"
      fish_completion.install "completions/fish/podman.fish"
    else
      paths = Dir["**/*.go"].select do |file|
        (buildpath/file).read.lines.grep(%r{/etc/containers/}).any?
      end
      inreplace paths, "/etc/containers/", etc/"containers/"
      ENV.O0
      ENV["PREFIX"] = prefix
      ENV["HELPER_BINARIES_DIR"] = opt_libexec/"podman"
      system "make"
      system "make", "install", "install.completions"
      (prefix/"etc/containers/policy.json").write <<~EOS
        {"default":[{"type":"insecureAcceptAnything"}]}
      EOS
      (prefix/"etc/containers/storage.conf").write <<~EOS
        [storage]
        driver="overlay"
      EOS
      (prefix/"etc/containers/registries.conf").write <<~EOS
        unqualified-search-registries=["docker.io"]
      EOS
      resource("catatonit").stage do
        system "./autogen.sh"
        system "./configure"
        system "make"
        mv "catatonit", libexec/"podman/"
      end
      resource("netavark").stage do
        system "make"
        mv "bin/netavark", libexec/"podman/"
      end
      resource("aardvark-dns").stage do
        system "make"
        mv "bin/aardvark-dns", libexec/"podman/"
      end
    end
  end
  def caveats
    on_linux do
      <<~EOS
        You need "newuidmap" and "newgidmap" binaries installed system-wide
        for rootless containers to work properly.
      EOS
    end
    on_macos do
      <<-EOS
        In order to run containers locally, podman depends on a Linux kernel.
        One can be started manually using `podman machine` from this package.
        To start a podman VM automatically at login, also install the cask
        "podman-desktop".
      EOS
    end
  end
  service do
    run linux: [opt_bin/"podman", "system", "service", "--time=0"]
    environment_variables PATH: std_service_path_env
    working_dir HOMEBREW_PREFIX
  end
  test do
    assert_match "podman-remote version #{version}", shell_output("#{bin}/podman-remote -v")
    out = shell_output("#{bin}/podman-remote info 2>&1", 125)
    assert_match "Cannot connect to Podman", out
    if OS.mac?
      out = shell_output("#{bin}/podman-remote machine init --image-path fake-testi123 fake-testvm 2>&1", 125)
      assert_match "Error: open fake-testi123: no such file or directory", out
    else
      assert_equal %W[
        #{bin}/podman
        #{bin}/podman-remote
        #{bin}/podmansh
      ].sort, Dir[bin/"*"].sort
      assert_equal %W[
        #{libexec}/podman/catatonit
        #{libexec}/podman/netavark
        #{libexec}/podman/aardvark-dns
        #{libexec}/podman/quadlet
        #{libexec}/podman/rootlessport
      ].sort, Dir[libexec/"podman/*"].sort
      out = shell_output("file #{libexec}/podman/catatonit")
      assert_match "statically linked", out
    end
  end
end
