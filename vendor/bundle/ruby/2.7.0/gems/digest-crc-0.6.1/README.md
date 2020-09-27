# Digest CRC

[![Build Status](https://travis-ci.org/postmodern/digest-crc.svg?branch=master)](https://travis-ci.org/postmodern/digest-crc)

* [Source](https://github.com/postmodern/digest-crc)
* [Issues](https://github.com/postmodern/digest-crc/issues)
* [Documentation](http://rubydoc.info/gems/digest-crc/frames)
* [Email](mailto:postmodern.mod3 at gmail.com)

## Description

Adds support for calculating Cyclic Redundancy Check (CRC) to the Digest
module.

## Features

* Provides support for the following CRC algorithms:
  * {Digest::CRC1 CRC1}
  * {Digest::CRC5 CRC5}
  * {Digest::CRC8 CRC8}
  * {Digest::CRC8_1Wire CRC8 1-Wire}
  * {Digest::CRC15 CRC15}
  * {Digest::CRC16 CRC16}
  * {Digest::CRC16CCITT CRC16 CCITT}
  * {Digest::CRC16DNP CRC16 DNP}
  * {Digest::CRC16Genibus CRC16 Genibus}
  * {Digest::CRC16Kermit CRC16 Kermit}
  * {Digest::CRC16Modbus CRC16 Modbus}
  * {Digest::CRC16USB CRC16 USB}
  * {Digest::CRC16X25 CRC16 X25}
  * {Digest::CRC16XModem CRC16 XModem}
  * {Digest::CRC16ZModem CRC16 ZModem}
  * {Digest::CRC16QT CRC16 QT}
  * {Digest::CRC24 CRC24}
  * {Digest::CRC32 CRC32}
  * {Digest::CRC32BZip2 CRC32 BZip2}
  * {Digest::CRC32c CRC32c}
  * {Digest::CRC32Jam CRC32 Jam}
  * {Digest::CRC32MPEG CRC32 MPEG}
  * {Digest::CRC32POSIX CRC32 POSIX}
  * {Digest::CRC32XFER CRC32 XFER}
  * {Digest::CRC64 CRC64}
  * {Digest::CRC64Jones CRC64 Jones}
  * {Digest::CRC64XZ CRC64 XZ}
* Pure Ruby implementation.
* Provides CRC Tables for optimized calculations.
* Supports _optional_ C extensions which increases performance by ~40x.
  * If the C extensions cannot be compiled for whatever reason, digest-crc
    will automatically fallback to the pure-Ruby implementation.

## Install

```
gem install digest-crc
```

## Examples

Calculate a CRC32:

```ruby
require 'digest/crc32'

Digest::CRC32.hexdigest('hello')
# => "3610a686"
```

Calculate a CRC32 of a file:

```ruby
Digest::CRC32.file('README.md')
# => #<Digest::CRC32: 127ad531>
```

Incrementally calculate a CRC32:

```ruby
crc = Digest::CRC32.new
crc << 'one'
crc << 'two'
crc << 'three'
crc.hexdigest
# => "09e1c092"
```

Directly access the checksum:

```ruby
crc.checksum
# => 165789842
```

Defining your own CRC class:

```ruby
require 'digest/crc32'

module Digest
  class CRC3000 < CRC32

    WIDTH = 4

    INIT_CRC = 0xffffffff

    XOR_MASK = 0xffffffff

    TABLE = [
      # ....
    ].freeze

    def update(data)
      data.each_byte do |b|
        @crc = (((@crc >> 8) & 0x00ffffff) ^ @table[(@crc ^ b) & 0xff])
      end

      return self
    end
  end
end
```

## Benchmarks

### Pure Ruby (ruby 2.7.1)

    $ bundle exec rake clean
    $ bundle exec ./benchmarks.rb
    Loading Digest::CRC classes ...
    Generating 1000 8Kb lengthed strings ...
    Benchmarking Digest::CRC classes ...
           user     system      total        real
    Digest::CRC1#update  0.349756   0.000002   0.349758 (  0.351427)
    Digest::CRC5#update  1.175206   0.000049   1.175255 (  1.180975)
    Digest::CRC8#update  1.023536   0.000015   1.023551 (  1.029017)
    Digest::CRC8_1Wire#update  1.012156   0.000000   1.012156 (  1.017342)
    Digest::CRC15#update  1.187286   0.000005   1.187291 (  1.193634)
    Digest::CRC16#update  0.998527   0.000013   0.998540 (  1.003940)
    Digest::CRC16CCITT#update  1.179864   0.000005   1.179869 (  1.186134)
    Digest::CRC16DNP#update  1.018969   0.000003   1.018972 (  1.025248)
    Digest::CRC16Genibus#update  1.196754   0.000065   1.196819 (  1.203605)
    Digest::CRC16Modbus#update  1.007367   0.000000   1.007367 (  1.012325)
    Digest::CRC16X25#update  1.044127   0.000000   1.044127 (  1.052010)
    Digest::CRC16USB#update  1.012804   0.000000   1.012804 (  1.018324)
    Digest::CRC16X25#update  1.009694   0.000000   1.009694 (  1.015890)
    Digest::CRC16XModem#update  1.210814   0.000000   1.210814 (  1.217951)
    Digest::CRC16ZModem#update  1.175239   0.000000   1.175239 (  1.181395)
    Digest::CRC24#update  1.207431   0.000000   1.207431 (  1.213373)
    Digest::CRC32#update  1.012334   0.000000   1.012334 (  1.017671)
    Digest::CRC32BZip2#update  1.190351   0.000000   1.190351 (  1.196567)
    Digest::CRC32c#update  1.021147   0.000000   1.021147 (  1.027035)
    Digest::CRC32Jam#update  1.002365   0.000000   1.002365 (  1.007202)
    Digest::CRC32MPEG#update  1.161925   0.000000   1.161925 (  1.168058)
    Digest::CRC32POSIX#update  1.191860   0.000967   1.192827 (  1.198722)
    Digest::CRC32XFER#update  1.217692   0.000000   1.217692 (  1.224075)
    Digest::CRC64#update  3.084106   0.000000   3.084106 (  3.106840)
    Digest::CRC64Jones#update  3.016687   0.000000   3.016687 (  3.038963)
    Digest::CRC64XZ#update  3.019690   0.000000   3.019690 (  3.040971)

### C extensions (ruby 2.7.1)
o
    $ bundle exec rake build:c_exts
    ...
    $ bundle exec ./benchmarks.rb
    Loading Digest::CRC classes ...
    Generating 1000 8Kb lengthed strings ...
    Benchmarking Digest::CRC classes ...
           user     system      total        real
    Digest::CRC1#update  0.356025   0.000016   0.356041 (  0.365345)
    Digest::CRC5#update  0.023957   0.000001   0.023958 (  0.024835)
    Digest::CRC8#update  0.021254   0.000007   0.021261 (  0.024647)
    Digest::CRC8_1Wire#update  0.039129   0.000000   0.039129 (  0.042417)
    Digest::CRC15#update  0.030285   0.000000   0.030285 (  0.030560)
    Digest::CRC16#update  0.023003   0.000000   0.023003 (  0.023267)
    Digest::CRC16CCITT#update  0.028207   0.000000   0.028207 (  0.028467)
    Digest::CRC16DNP#update  0.022861   0.000000   0.022861 (  0.023111)
    Digest::CRC16Genibus#update  0.028041   0.000000   0.028041 (  0.028359)
    Digest::CRC16Modbus#update  0.022931   0.000009   0.022940 (  0.023560)
    Digest::CRC16X25#update  0.022808   0.000000   0.022808 (  0.023054)
    Digest::CRC16USB#update  0.022258   0.000882   0.023140 (  0.023418)
    Digest::CRC16X25#update  0.022816   0.000000   0.022816 (  0.023084)
    Digest::CRC16XModem#update  0.027984   0.000000   0.027984 (  0.028269)
    Digest::CRC16ZModem#update  0.027968   0.000000   0.027968 (  0.028214)
    Digest::CRC24#update  0.028426   0.000000   0.028426 (  0.028687)
    Digest::CRC32#update  0.022805   0.000000   0.022805 (  0.023043)
    Digest::CRC32BZip2#update  0.025519   0.000000   0.025519 (  0.025797)
    Digest::CRC32c#update  0.022807   0.000000   0.022807 (  0.023069)
    Digest::CRC32Jam#update  0.023006   0.000000   0.023006 (  0.023231)
    Digest::CRC32MPEG#update  0.025536   0.000000   0.025536 (  0.025861)
    Digest::CRC32POSIX#update  0.025557   0.000000   0.025557 (  0.025841)
    Digest::CRC32XFER#update  0.025310   0.000000   0.025310 (  0.025599)
    Digest::CRC64#update  0.023182   0.000000   0.023182 (  0.023421)
    Digest::CRC64Jones#update  0.022916   0.000000   0.022916 (  0.023139)
    Digest::CRC64XZ#update  0.022879   0.000000   0.022879 (  0.023131)

### Pure Ruby (jruby 9.2.12.0)

    $ bundle exec ./benchmarks.rb
    Loading Digest::CRC classes ...
    Generating 1000 8Kb lengthed strings ...
    Benchmarking Digest::CRC classes ...
           user     system      total        real
    Digest::CRC1#update  1.030000   0.090000   1.120000 (  0.511189)
    Digest::CRC5#update  1.620000   0.060000   1.680000 (  1.096031)
    Digest::CRC8#update  1.560000   0.070000   1.630000 (  1.083921)
    Digest::CRC8_1Wire#update  0.930000   0.040000   0.970000 (  0.927024)
    Digest::CRC15#update  1.590000   0.070000   1.660000 (  1.132566)
    Digest::CRC16#update  1.650000   0.060000   1.710000 (  1.074508)
    Digest::CRC16CCITT#update  1.610000   0.060000   1.670000 (  1.190860)
    Digest::CRC16DNP#update  1.270000   0.010000   1.280000 (  0.938132)
    Digest::CRC16Genibus#update  1.620000   0.030000   1.650000 (  1.148556)
    Digest::CRC16Modbus#update  1.070000   0.020000   1.090000 (  0.881455)
    Digest::CRC16X25#update  1.110000   0.010000   1.120000 (  0.945366)
    Digest::CRC16USB#update  1.140000   0.000000   1.140000 (  0.984367)
    Digest::CRC16X25#update  0.920000   0.010000   0.930000 (  0.872541)
    Digest::CRC16XModem#update  1.530000   0.010000   1.540000 (  1.092838)
    Digest::CRC16ZModem#update  1.720000   0.010000   1.730000 (  1.164787)
    Digest::CRC24#update  1.810000   0.020000   1.830000 (  1.084953)
    Digest::CRC32#update  1.590000   0.010000   1.600000 (  1.105553)
    Digest::CRC32BZip2#update  1.520000   0.010000   1.530000 (  1.070839)
    Digest::CRC32c#update  0.960000   0.010000   0.970000 (  0.881989)
    Digest::CRC32Jam#update  1.030000   0.010000   1.040000 (  0.907208)
    Digest::CRC32MPEG#update  1.420000   0.010000   1.430000 (  0.994035)
    Digest::CRC32POSIX#update  1.530000   0.020000   1.550000 (  1.106366)
    Digest::CRC32XFER#update  1.650000   0.010000   1.660000 (  1.097647)
    Digest::CRC64#update  3.440000   0.030000   3.470000 (  2.771806)
    Digest::CRC64Jones#update  2.630000   0.010000   2.640000 (  2.628016)
    Digest::CRC64XZ#update  3.200000   0.020000   3.220000 (  2.913442)

## Thanks

Special thanks go out to the [pycrc](http://www.tty1.net/pycrc/) library
which is able to generate C source-code for all of the CRC algorithms,
including their CRC Tables.

## License

Copyright (c) 2010-2020 Hal Brodigan

See {file:LICENSE.txt} for license information.
