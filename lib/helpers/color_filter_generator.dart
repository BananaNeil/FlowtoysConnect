import 'dart:math';

class ColorFilterGenerator {
    static List<double> hueAdjustMatrix({double value, initialValue}) {
      initialValue = initialValue.remainder(1) ?? 0.5;
      value = value.remainder(1) ?? initialValue;

      if (value <= initialValue)
        value = (((value / initialValue) - 1)).clamp(-1.0, 0) * pi;
      else
        value = ((((value - initialValue) / (1 - initialValue)))).clamp(0, 1.0) * pi;

      if (value == 0)
        return [
          1,0,0,0,0,
          0,1,0,0,0,
          0,0,1,0,0,
          0,0,0,1,0,
        ];

      double cosVal = cos(value);
      double sinVal = sin(value);
      double lumR = 0.213;
      double lumG = 0.715;
      double lumB = 0.072;

      return List<double>.from(<double>[
        (lumR + (cosVal * (1 - lumR))) + (sinVal * (-lumR)), (lumG + (cosVal * (-lumG))) + (sinVal * (-lumG)), (lumB + (cosVal * (-lumB))) + (sinVal * (1 - lumB)), 0, 0, (lumR + (cosVal * (-lumR))) + (sinVal * 0.143), (lumG + (cosVal * (1 - lumG))) + (sinVal * 0.14), (lumB + (cosVal * (-lumB))) + (sinVal * (-0.283)), 0, 0, (lumR + (cosVal * (-lumR))) + (sinVal * (-(1 - lumR))), (lumG + (cosVal * (-lumG))) + (sinVal * lumG), (lumB + (cosVal * (1 - lumB))) + (sinVal * lumB), 0, 0, 0, 0, 0, 1, 0,
      ]).map((i) => i.toDouble()).toList();
    }

    static List<double> brightnessAdjustMatrix({double value, initialValue}) {
      initialValue = initialValue ?? 0.5;
      value = value ?? initialValue;
      if (value <= initialValue)
        value = (((value / initialValue) - 1) * 255).clamp(-255.0, 0);
      else
        value = ((((value - initialValue) / (1 - initialValue))) * 100).clamp(0, 100.0);

      if (value == 0)
        return [
          1,0,0,0,0,
          0,1,0,0,0,
          0,0,1,0,0,
          0,0,0,1,0,
        ];

      return List<double>.from(<double>[
        1, 0, 0, 0, value, 0, 1, 0, 0, value, 0, 0, 1, 0, value, 0, 0, 0, 1, 0
      ]).map((i) => i.toDouble()).toList();
    }

    static List<double> saturationAdjustMatrix({double value, double initialValue}) {
      initialValue = initialValue ?? 0.5;
      value = value ?? initialValue;
      if (value <= initialValue)
        value = (((value / initialValue) - 1) * 100).clamp(-100.0, 0);
      else
        value = ((((value - initialValue) / (1 - initialValue))) * 100).clamp(0, 100.0);

      if (value == 0)
        return [
          1,0,0,0,0,
          0,1,0,0,0,
          0,0,1,0,0,
          0,0,0,1,0,
        ];

      double x = ((1 + ((value > 0) ? ((3 * value) / 100) : (value / 100)))).toDouble();
      double lumR = 0.3086;
      double lumG = 0.6094;
      double lumB = 0.082;

      return List<double>.from(<double>[
        (lumR * (1 - x)) + x, lumG * (1 - x), lumB * (1 - x),
        0, 0,
        lumR * (1 - x),
        (lumG * (1 - x)) + x,
        lumB * (1 - x),
        0, 0,
        lumR * (1 - x),
        lumG * (1 - x),
        (lumB * (1 - x)) + x,
        0, 0, 0, 0, 0, 1, 0,
      ]).map((i) => i.toDouble()).toList();
    }
}
