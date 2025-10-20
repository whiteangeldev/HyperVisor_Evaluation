# Building Xen from Source with RTDS Support

## ⚠️ WARNING

This is a **time-consuming process** (2-4 hours) and requires:
- Building Xen hypervisor from source
- Installing build dependencies (~500MB)
- Replacing Ubuntu's Xen package
- Risk of boot issues

**Only proceed if:**
- You specifically need Xen (not ACRN)
- You need RTDS scheduler specifically
- You can afford the time and risk

---

## Quick Overview

Ubuntu's Xen package lacks RTDS because `CONFIG_SCHED_RTDS` is not enabled.

**Solution:** Build Xen from source with RTDS enabled.

---

## Build Process

### 1. Install Build Dependencies

```bash
sudo apt update
sudo apt install -y \
    build-essential \
    git \
    bcc \
    bin86 \
    gawk \
    bridge-utils \
    iproute2 \
    libcurl4-openssl-dev \
    bzip2 \
    module-init-tools \
    transfig \
    tgif \
    texinfo \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    libpci-dev \
    mercurial \
    make \
    gcc \
    libc6-dev \
    zlib1g-dev \
    python3-dev \
    python3-twisted \
    libncurses5-dev \
    patch \
    libvncserver-dev \
    libsdl-dev \
    libjpeg-dev \
    iasl \
    libbz2-dev \
    e2fslibs-dev \
    ocaml-nox \
    libx11-dev \
    bison \
    flex \
    ocaml-findlib \
    xz-utils \
    gettext \
    libyajl-dev \
    libpixman-1-dev \
    libaio-dev \
    markdown \
    pandoc \
    checkpolicy \
    uuid-dev \
    libssl-dev \
    python3-setuptools
```

### 2. Download Xen Source

```bash
cd ~
git clone https://xenbits.xen.org/git-http/xen.git
cd xen
git checkout RELEASE-4.17.4
```

### 3. Configure Build with RTDS

```bash
# Configure
./configure --enable-systemd \
    --prefix=/usr \
    --with-xen-scriptdir=/etc/xen/scripts \
    --with-sysconfig-leaf-dir=default

# Enable RTDS in config
echo "sched-rtds := y" >> Config.mk
```

### 4. Build Xen

```bash
make world -j$(nproc)
```

**Time:** 30-60 minutes depending on CPU

### 5. Install

```bash
# Remove Ubuntu's Xen first
sudo apt remove --purge xen-hypervisor-*

# Install custom build
sudo make install

# Update GRUB
sudo update-grub
```

### 6. Reboot and Verify

```bash
sudo reboot

# After reboot
sudo xl info | grep xen_scheduler
# Should now show: rtds (if sched=rtds in GRUB)
```

---

## Easier Alternative: Use Our Build Script

**Not recommended unless you really need this.**

Time: 2-4 hours total

Risk: High (custom hypervisor)

---

## RECOMMENDED: Use ACRN Instead

Intel ACRN provides:
- ✅ Native RT design (no build needed)
- ✅ < 10μs latency
- ✅ Easier to set up
- ✅ Better for embedded/RT

```bash
cd ~/rt-hypervisor-poc/scripts
./26_master_setup_acrn.sh
```

---

*Only build Xen from source if ACRN doesn't meet your specific requirements.*

