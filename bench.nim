import ./src/dtoa
import criterion

let cfg = newDefaultConfig()
benchmark(cfg):
  iterator gengen(): (float64, string) =
    yield (0.0, "0.0")
    yield (-123.0, "-123.0")
    yield (1234e7, "12340000000.0")
    yield (1234e-2, "12.34")
    yield (1234e-6, "0.001234")
    yield (1e30, "1e30")
    yield (1234e30, "1.234e33")
    yield (1.0 / 3.0, "0.3333333333333333")

  iterator gengengen(): (float64, string) =
    yield (0.0, "0.0")
    yield (-123.0, "-123.0")
    yield (1234e7, "12340000000.0")
    yield (1234e-2, "12.34")
    yield (1234e-6, "0.001234")
    yield (1e30, "1e+30")
    yield (1234e30, "1.234e+33")
    yield (1.0 / 3.0, "0.3333333333333333")

  func usingThis() {.measure.} =
    for val, expect in gengen():
      let got = dtoa(val)
      doAssert got == expect
  func usingThat() {.measure.} =
    for val, expect in gengengen():
      let got = $val
      doAssert got == expect
