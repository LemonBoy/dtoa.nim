import dtoa

doAssert "0.0" == dtoa(0.0)
doAssert "-0.0" == dtoa(-0.0)
doAssert "1.0" == dtoa(1.0)
doAssert "-1.0" == dtoa(-1.0)
doAssert "1.2345" == dtoa(1.2345)
doAssert "1.2345678" == dtoa(1.2345678)
doAssert "0.123456789012" == dtoa(0.123456789012)
doAssert "1234567.8" == dtoa(1234567.8)
doAssert "-79.39773355813419" == dtoa(-79.39773355813419)
doAssert "0.000001" == dtoa(0.000001)
doAssert "1e-7" == dtoa(0.0000001)
doAssert "1e30" == dtoa(1e30)
doAssert "1.234567890123456e30" == dtoa(1.234567890123456e30)
# Min subnormal positive double
doAssert "5e-324" == dtoa(5e-324)
# Max subnormal positive double
doAssert "2.225073858507201e-308" == dtoa(2.225073858507201e-308)
# Min normal positive double
doAssert "2.2250738585072014e-308" == dtoa(2.2250738585072014e-308)
# Max double
doAssert "1.7976931348623157e308" == dtoa(1.7976931348623157e308)
# Bugfix backported from rapidJSON
doAssert "0.3333333333333333" == dtoa(1.0 / 3.0)
# Inf
doAssert "inf" == dtoa(1.0 / 0.0)
