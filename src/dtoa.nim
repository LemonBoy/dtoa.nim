import bitops

# https://github.com/miloyip/dtoa-benchmark/blob/master/src/milo/dtoa_milo.h
# https://github.com/Tencent/rapidjson/commit/fe550f38669fe0f488926c1ef0feb6c101f586d6

const kDpSignificandMask = 0x000FFFFFFFFFFFFF'u64
const kDpHiddenBit = 0x0010000000000000'u64
const kDiySignificandSize = 64
const kDpSignificandSize = 52
const kDpExponentBias = 0x3FF + kDpSignificandSize
const kDpMinExponent = -kDpExponentBias
const kDpExponentMask = 0x7FF0000000000000'u64

type
  DiyFp = object
    f: uint64
    e: int

func newDiyFp(d: float64): DiyFp =
  let u64 = cast[uint64](d)
  let biased_e = (u64 and kDpExponentMask) shr kDpSignificandSize
  let significand = (u64 and kDpSignificandMask)
  if (biased_e != 0):
    result.f = significand + kDpHiddenBit
    result.e = int(biased_e - kDpExponentBias)
  else:
    result.f = significand
    result.e = kDpMinExponent + 1

func newDiyFp(f: uint64, e: int): DiyFp =
  result.f = f
  result.e = e

func `-`(self, rhs: DiyFp): DiyFp =
  doAssert self.e == rhs.e
  doAssert self.f >= rhs.f
  result.f = self.f - rhs.f
  result.e = self.e

func `*`(self, rhs: DiyFp): DiyFp =
  const
    M32 = 0xFFFFFFFF'u64
  let
    a = self.f shr 32
    b = self.f and M32
    c = rhs.f shr 32
    d = rhs.f and M32
    ac = a * c
    bc = b * c
    ad = a * d
    bd = b * d
  var
    tmp = (bd shr 32) + (ad and M32) + (bc and M32)
  tmp += 1'u64 shl 31 # mult_round
  result = newDiyFp(ac + (ad shr 32) + (bc shr 32) + (tmp shr 32),
                    self.e + rhs.e + 64)

func normalize(self: DiyFp): DiyFp =
  result = self
  let s = countLeadingZeroBits(self.f)
  result = newDiyFp(self.f shl s, self.e - s)

func normalizeBoundary(self: DiyFp): DiyFp =
  result = self
  while (result.f and (kDpHiddenBit shl 1)) == 0:
    result.f = result.f shl 1
    result.e = result.e - 1
  result.f = result.f shl (kDiySignificandSize - kDpSignificandSize - 2);
  result.e = result.e - (kDiySignificandSize - kDpSignificandSize - 2);
  # let s = countLeadingZeroBits(result.f)
  # result.f = self.f shl s
  # result.e = self.e - s

func normalizedBoundaries(self: DiyFp):
  tuple[minus: DiyFp, plus: DiyFp] =
  result.plus = newDiyFp((self.f shl 1) + 1, self.e - 1).normalizeBoundary()
  if self.f == kDpHiddenBit:
    result.minus = newDiyFp((self.f shl 2) - 1, self.e - 2)
  else:
    result.minus = newDiyFp((self.f shl 1) - 1, self.e - 1)
  result.minus.f = result.minus.f shl (result.minus.e - result.plus.e)
  result.minus.e = result.plus.e

func getCachedPower(e: int): tuple[fp: DiyFp, K: int] =
  # 10^-348, 10^-340, ..., 10^340
  const kCachedPowers_F = [
    0xfa8fd5a0081c0288'u64, 0xbaaee17fa23ebf76'u64,
    0x8b16fb203055ac76'u64, 0xcf42894a5dce35ea'u64,
    0x9a6bb0aa55653b2d'u64, 0xe61acf033d1a45df'u64,
    0xab70fe17c79ac6ca'u64, 0xff77b1fcbebcdc4f'u64,
    0xbe5691ef416bd60c'u64, 0x8dd01fad907ffc3c'u64,
    0xd3515c2831559a83'u64, 0x9d71ac8fada6c9b5'u64,
    0xea9c227723ee8bcb'u64, 0xaecc49914078536d'u64,
    0x823c12795db6ce57'u64, 0xc21094364dfb5637'u64,
    0x9096ea6f3848984f'u64, 0xd77485cb25823ac7'u64,
    0xa086cfcd97bf97f4'u64, 0xef340a98172aace5'u64,
    0xb23867fb2a35b28e'u64, 0x84c8d4dfd2c63f3b'u64,
    0xc5dd44271ad3cdba'u64, 0x936b9fcebb25c996'u64,
    0xdbac6c247d62a584'u64, 0xa3ab66580d5fdaf6'u64,
    0xf3e2f893dec3f126'u64, 0xb5b5ada8aaff80b8'u64,
    0x87625f056c7c4a8b'u64, 0xc9bcff6034c13053'u64,
    0x964e858c91ba2655'u64, 0xdff9772470297ebd'u64,
    0xa6dfbd9fb8e5b88f'u64, 0xf8a95fcf88747d94'u64,
    0xb94470938fa89bcf'u64, 0x8a08f0f8bf0f156b'u64,
    0xcdb02555653131b6'u64, 0x993fe2c6d07b7fac'u64,
    0xe45c10c42a2b3b06'u64, 0xaa242499697392d3'u64,
    0xfd87b5f28300ca0e'u64, 0xbce5086492111aeb'u64,
    0x8cbccc096f5088cc'u64, 0xd1b71758e219652c'u64,
    0x9c40000000000000'u64, 0xe8d4a51000000000'u64,
    0xad78ebc5ac620000'u64, 0x813f3978f8940984'u64,
    0xc097ce7bc90715b3'u64, 0x8f7e32ce7bea5c70'u64,
    0xd5d238a4abe98068'u64, 0x9f4f2726179a2245'u64,
    0xed63a231d4c4fb27'u64, 0xb0de65388cc8ada8'u64,
    0x83c7088e1aab65db'u64, 0xc45d1df942711d9a'u64,
    0x924d692ca61be758'u64, 0xda01ee641a708dea'u64,
    0xa26da3999aef774a'u64, 0xf209787bb47d6b85'u64,
    0xb454e4a179dd1877'u64, 0x865b86925b9bc5c2'u64,
    0xc83553c5c8965d3d'u64, 0x952ab45cfa97a0b3'u64,
    0xde469fbd99a05fe3'u64, 0xa59bc234db398c25'u64,
    0xf6c69a72a3989f5c'u64, 0xb7dcbf5354e9bece'u64,
    0x88fcf317f22241e2'u64, 0xcc20ce9bd35c78a5'u64,
    0x98165af37b2153df'u64, 0xe2a0b5dc971f303a'u64,
    0xa8d9d1535ce3b396'u64, 0xfb9b7cd9a4a7443c'u64,
    0xbb764c4ca7a44410'u64, 0x8bab8eefb6409c1a'u64,
    0xd01fef10a657842c'u64, 0x9b10a4e5e9913129'u64,
    0xe7109bfba19c0c9d'u64, 0xac2820d9623bf429'u64,
    0x80444b5e7aa7cf85'u64, 0xbf21e44003acdd2d'u64,
    0x8e679c2f5e44ff8f'u64, 0xd433179d9c8cb841'u64,
    0x9e19db92b4e31ba9'u64, 0xeb96bf6ebadf77d9'u64,
    0xaf87023b9bf0ee6b'u64
  ]
  const kCachedPowers_E = [
    -1220'i16,
           -1193, -1166, -1140, -1113, -1087, -1060, -1034, -1007,  -980,
     -954,  -927,  -901,  -874,  -847,  -821,  -794,  -768,  -741,  -715,
     -688,  -661,  -635,  -608,  -582,  -555,  -529,  -502,  -475,  -449,
     -422,  -396,  -369,  -343,  -316,  -289,  -263,  -236,  -210,  -183,
     -157,  -130,  -103,   -77,   -50,   -24,     3,    30,    56,    83,
      109,   136,   162,   189,   216,   242,   269,   295,   322,   348,
      375,   402,   428,   455,   481,   508,   534,   561,   588,   614,
      641,   667,   694,   720,   747,   774,   800,   827,   853,   880,
      907,   933,   960,   986,  1013,  1039,  1066
  ]

  # int k = static_cast<int>(ceil((-61 - e) * 0.30102999566398114)) + 374;
  let # dk must be positive, so can do ceiling in positive
    dk = float64(-61 - e) * 0.30102999566398114'f64 + 347 
  var k = int(dk)

  if float64(k) != dk:
    k += 1

  let
    index = uint32((k shr 3) + 1)

  doAssert index < kCachedPowers_F.len

  result.fp.f = kCachedPowers_F[index]
  result.fp.e = kCachedPowers_E[index]
  result.K = -(-348 + int(index shl 3)) # decimal exponent no need lookup table

func grisuRound(buffer: ptr UncheckedArray[byte], len: int, delta, rest, ten_kappa, wp_w: uint64) {.inline.} =
  var rest = rest
  while (rest < wp_w and delta - rest >= ten_kappa and
    ((rest + ten_kappa < wp_w) or  # closer
      (wp_w - rest > rest + ten_kappa - wp_w))):
    buffer[len - 1] -= 1;
    rest += ten_kappa;

func countDecimalDigit32(n: uint32): int {.inline.} =
  # Simple pure C++ implementation was faster than __builtin_clz version in this situation.
  if (n < 10): return 1
  if (n < 100): return 2
  if (n < 1000): return 3
  if (n < 10000): return 4
  if (n < 100000): return 5
  if (n < 1000000): return 6
  if (n < 10000000): return 7
  if (n < 100000000): return 8
  if (n < 1000000000): return 9
  return 10

func digitGen(W, Mp: DiyFp, delta: uint64, buffer: ptr UncheckedArray[byte], K: int): (int, int) =
  const
    kPow10 = [1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000 ]
  let
    one = newDiyFp(uint64(1) shl -Mp.e, Mp.e)
    wp_w = Mp - W
  var 
    p1 = uint32(Mp.f shr -one.e)
    p2 = Mp.f and (one.f - 1)
    kappa = countDecimalDigit32(p1)

  var
    K = K
    len = 0

  while (kappa > 0):
    var d: uint32
    case kappa:
    of 10:
      d = p1 div 1000000000; p1 = p1 mod 1000000000
    of  9:
      d = p1 div  100000000; p1 = p1 mod  100000000
    of  8:
      d = p1 div   10000000; p1 = p1 mod   10000000
    of  7:
      d = p1 div    1000000; p1 = p1 mod    1000000
    of  6:
      d = p1 div     100000; p1 = p1 mod     100000
    of  5:
      d = p1 div      10000; p1 = p1 mod      10000
    of  4:
      d = p1 div       1000; p1 = p1 mod       1000
    of  3:
      d = p1 div        100; p1 = p1 mod        100
    of  2:
      d = p1 div         10; p1 = p1 mod         10
    of  1:
      d = p1               ; p1 =                 0
    else:
      doAssert false

    if (d != 0 or len != 0):
      buffer[len] = byte(ord('0') + int(d))
      len += 1
    kappa -= 1

    let tmp = (uint64(p1) shl -one.e) + p2
    if tmp <= delta:
      K += kappa
      grisuRound(buffer, len, delta, tmp, uint64(kPow10[kappa]) shl -one.e, wp_w.f)

      result[0] = K
      result[1] = len

      return

  var delta = delta
  # kappa = 0
  while true:
    p2 *= 10
    delta = delta * 10
    let d = char(p2 shr -one.e)
    if (d != char(0) or len != 0):
      buffer[len] = byte(ord('0') + int(d))
      len += 1
    p2 = p2 and (one.f - 1)
    kappa -= 1
    if p2 < delta:
      K += kappa
      # bugfix
      let index = if -kappa < 9: -kappa else: 0
      grisuRound(buffer, len, delta, p2, one.f, wp_w.f * uint64(kPow10[index]))

      result[0] = K
      result[1] = len

      return

func grisu2(value: float64, buffer: ptr UncheckedArray[byte]): (int, int) =
  let v = newDiyFp(value)
  let (w_m, w_p) = v.normalizedBoundaries()

  let
    (c_mk, K) = getCachedPower(w_p.e)
    W = v.normalize() * c_mk
  var
    Wp = w_p * c_mk
    Wm = w_m * c_mk
  Wm.f += 1
  Wp.f -= 1

  result = digitGen(W, Wp, Wp.f - Wm.f, buffer, K)

func writeExponent(K, len: int, buffer: ptr UncheckedArray[byte]): int =
  const cDigitsLut = [
    '0', '0', '0', '1', '0', '2', '0', '3', '0', '4', '0', '5', '0', '6', '0', '7', '0', '8', '0', '9',
    '1', '0', '1', '1', '1', '2', '1', '3', '1', '4', '1', '5', '1', '6', '1', '7', '1', '8', '1', '9',
    '2', '0', '2', '1', '2', '2', '2', '3', '2', '4', '2', '5', '2', '6', '2', '7', '2', '8', '2', '9',
    '3', '0', '3', '1', '3', '2', '3', '3', '3', '4', '3', '5', '3', '6', '3', '7', '3', '8', '3', '9',
    '4', '0', '4', '1', '4', '2', '4', '3', '4', '4', '4', '5', '4', '6', '4', '7', '4', '8', '4', '9',
    '5', '0', '5', '1', '5', '2', '5', '3', '5', '4', '5', '5', '5', '6', '5', '7', '5', '8', '5', '9',
    '6', '0', '6', '1', '6', '2', '6', '3', '6', '4', '6', '5', '6', '6', '6', '7', '6', '8', '6', '9',
    '7', '0', '7', '1', '7', '2', '7', '3', '7', '4', '7', '5', '7', '6', '7', '7', '7', '8', '7', '9',
    '8', '0', '8', '1', '8', '2', '8', '3', '8', '4', '8', '5', '8', '6', '8', '7', '8', '8', '8', '9',
    '9', '0', '9', '1', '9', '2', '9', '3', '9', '4', '9', '5', '9', '6', '9', '7', '9', '8', '9', '9'
  ]

  var K = K
  var len = len
  if K < 0:
    buffer[len] = ord('-')
    len += 1
    K = -K

  if K >= 100:
    buffer[len] = byte(ord('0') + K div 100)
    len += 1
    K = K mod 100;
    buffer[len] = byte(cDigitsLut[K * 2 + 0])
    len += 1
    buffer[len] = byte(cDigitsLut[K * 2 + 1])
    len += 1
  elif K >= 10:
    buffer[len] = byte(cDigitsLut[K * 2 + 0])
    len += 1
    buffer[len] = byte(cDigitsLut[K * 2 + 1])
    len += 1
  else:
    buffer[len] = byte(ord('0') + K)
    len += 1

  result = len

func prettify(buffer: ptr UncheckedArray[byte], len, K: int): int =
  let kk = len + K # 10^(kk-1) <= v < 10^kk

  if len <= kk and kk <= 21:
    # 1234e7 -> 12340000000
    for i in len..<kk:
      buffer[i] = ord('0')
    buffer[kk] = ord('.')
    buffer[kk + 1] = ord('0')
    result = kk + 2
  elif 0 < kk and kk <= 21:
    # 1234e-2 -> 12.34
    moveMem(addr buffer[kk + 1], addr buffer[kk], len - kk)
    buffer[kk] = ord('.')
    result = len + 1
  elif -6 < kk and kk <= 0:
    # 1234e-6 -> 0.001234
    let offset = 2 - kk
    moveMem(addr buffer[offset], addr buffer[0], len)
    buffer[0] = ord('0')
    buffer[1] = ord('.')
    for i in 2..<offset:
      buffer[i] = ord('0')
    result = len + offset
  elif len == 1:
    # 1e30
    buffer[1] = ord('e')
    result = writeExponent(kk - 1, 2, buffer)
  else:
    # 1234e30 -> 1.234e33
    moveMem(addr buffer[2], addr buffer[1], len)
    buffer[1] = ord('.')
    buffer[len + 1] = ord('e')
    result = writeExponent(kk - 1, len + 2, buffer)

func dtoa*(value: float64): string =
  var
    value = value
    outOff = 0

  if value == 0:
    result = "0.0"
    return

  # Should be enough for every number out there
  result = newString(32)

  if value < 0:
    value = -value
    result[0] = '-'
    outOff += 1

  let
    pb = cast[ptr UncheckedArray[byte]](addr result[outOff])
    (K, len) = grisu2(value, pb)
    last = prettify(pb, len, K)

  result.setLen(last + outOff)
