class Scipy < Formula
  homepage 'http://www.scipy.org'
  url 'https://downloads.sourceforge.net/project/scipy/scipy/0.15.1/scipy-0.15.1.tar.gz'
  sha1 '7ef714ffe95230cd2ce78c51af18983bbe762f2e'
  head 'https://github.com/scipy/scipy.git'
  revision 1

  bottle do
    root_url "https://homebrew.bintray.com/bottles-python"
    sha256 "d82a0edd5050bc79b2f5100aa54de4d0d21f9409fb2238f00f80ff3eefa10192" => :yosemite
    sha256 "1bfcc2e4ea97a0922b5d1799d16ed9fbc1627e683efffc5df50bc0d7cb5787d9" => :mavericks
    sha256 "a89b1ceeea4976d0f7de038c33766d191e42708aa2ff564f81f0b4a7a660321a" => :mountain_lion
  end

  option "without-python", "Build without python2 support"

  depends_on 'swig' => :build
  depends_on :python => :recommended if MacOS.version <= :snow_leopard
  depends_on :python3 => :optional
  depends_on :fortran

  option "with-openblas", "Use openblas instead of Apple's Accelerate framework " \
                          "(required to build with gcc on OS X)"
  depends_on "homebrew/science/openblas" => (OS.mac? ? :optional : :recommended)

  numpy_options = []
  numpy_options << "with-python3" if build.with? "python3"
  numpy_options << "with-openblas" if build.with? "openblas"
  depends_on "numpy" => numpy_options

  cxxstdlib_check :skip

  # https://github.com/Homebrew/homebrew-python/issues/110
  # There are ongoing problems with gcc+accelerate.
  fails_with :gcc if OS.mac? && build.without?("openblas")

  def install
    # avoid user numpy distutils config files
    ENV["HOME"] = buildpath

    # https://github.com/numpy/numpy/issues/4203
    # https://github.com/Homebrew/homebrew-python/issues/209
    # https://github.com/Homebrew/homebrew-python/issues/233
    if OS.linux?
      ENV.append "FFLAGS", "-fPIC"
      ENV.append "LDFLAGS", "-shared"
    end

    config = <<-EOS.undent
      [DEFAULT]
      library_dirs = #{HOMEBREW_PREFIX}/lib
      include_dirs = #{HOMEBREW_PREFIX}/include

    EOS
    if build.with? 'openblas'
      # For maintainers:
      # Check which BLAS/LAPACK numpy actually uses via:
      # xcrun otool -L $(brew --prefix)/Cellar/scipy/<version>/lib/python2.7/site-packages/scipy/linalg/_flinalg.so
      # or the other .so files.
      openblas_dir = Formula["openblas"].opt_prefix
      # Setting ATLAS to None is important to prevent numpy from always
      # linking against Accelerate.framework.
      ENV['ATLAS'] = "None"
      ENV['BLAS'] = ENV['LAPACK'] = "#{openblas_dir}/lib/libopenblas.dylib"

      config << <<-EOS.undent
        [openblas]
        libraries = openblas
        library_dirs = #{openblas_dir}/lib
        include_dirs = #{openblas_dir}/include
      EOS
    end

    Pathname('site.cfg').write config

    # gfortran is gnu95
    Language::Python.each_python(build) do |python, version|
      ENV.prepend_create_path "PYTHONPATH", lib/"python#{version}/site-packages"
      system python, "setup.py", "build", "--fcompiler=gnu95"
      system python, *Language::Python.setup_install_args(prefix)
    end
  end

  # cleanup leftover .pyc files from previous installs which can cause problems
  # see https://github.com/Homebrew/homebrew-python/issues/185#issuecomment-67534979
  def post_install
    Language::Python.each_python(build) do |python, version|
      rm_f Dir["#{HOMEBREW_PREFIX}/lib/python#{version}/site-packages/scipy/**/*.pyc"]
    end
  end

  test do
    Language::Python.each_python(build) do |python, version|
      system python, "-c", "import scipy; assert not scipy.test().failures"
    end
  end

  def caveats
    if build.with? "python" and not Formula["python"].installed?
      homebrew_site_packages = Language::Python.homebrew_site_packages
      user_site_packages = Language::Python.user_site_packages "python"
      <<-EOS.undent
        If you use system python (that comes - depending on the OS X version -
        with older versions of numpy, scipy and matplotlib), you may need to
        ensure that the brewed packages come earlier in Python's sys.path with:
          mkdir -p #{user_site_packages}
          echo 'import sys; sys.path.insert(1, "#{homebrew_site_packages}")' >> #{user_site_packages}/homebrew.pth
      EOS
    end
  end

end
