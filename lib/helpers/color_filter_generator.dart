import 'dart:math';

class ColorFilterGenerator
{
    // static List<double> DELTA_INDEX = [0, 0.01, 0.02, 0.04, 0.05, 0.06, 0.07, 0.08, 0.1, 0.11, 0.12, 0.14, 0.15, 0.16, 0.17, 0.18, 0.2, 0.21, 0.22, 0.24, 0.25, 0.27, 0.28, 0.3, 0.32, 0.34, 0.36, 0.38, 0.4, 0.42, 0.44, 0.46, 0.48, 0.5, 0.53, 0.56, 0.59, 0.62, 0.65, 0.68, 0.71, 0.74, 0.77, 0.8, 0.83, 0.86, 0.89, 0.92, 0.95, 0.98, 1, 1.06, 1.12, 1.18, 1.24, 1.3, 1.36, 1.42, 1.48, 1.54, 1.6, 1.66, 1.72, 1.78, 1.84, 1.9, 1.96, 2, 2.12, 2.25, 2.37, 2.5, 2.62, 2.75, 2.87, 3, 3.2, 3.4, 3.6, 3.8, 4, 4.3, 4.7, 4.9, 5, 5.5, 6, 6.5, 6.8, 7, 7.3, 7.5, 7.8, 8, 8.4, 8.7, 9, 9.4, 9.6, 9.8, 10];
    //
    static List<double> hueAdjustMatrix({double value, initialValue}) {
      initialValue = initialValue ?? 0.5;
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
      var mat = List<double>.from(<double>[
        (lumR + (cosVal * (1 - lumR))) + (sinVal * (-lumR)), (lumG + (cosVal * (-lumG))) + (sinVal * (-lumG)), (lumB + (cosVal * (-lumB))) + (sinVal * (1 - lumB)), 0, 0, (lumR + (cosVal * (-lumR))) + (sinVal * 0.143), (lumG + (cosVal * (1 - lumG))) + (sinVal * 0.14), (lumB + (cosVal * (-lumB))) + (sinVal * (-0.283)), 0, 0, (lumR + (cosVal * (-lumR))) + (sinVal * (-(1 - lumR))), (lumG + (cosVal * (-lumG))) + (sinVal * lumG), (lumB + (cosVal * (1 - lumB))) + (sinVal * lumB), 0, 0, 0, 0, 0, 1, 0,
      ]).map((i) => i.toDouble()).toList();
      return mat;
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
        List<double> mat = List<double>.from(<double>[
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

      return mat;
    }

    // static double cleanValue(double p_val, double p_limit)
    // {
    //     return min(p_limit, max(-p_limit, p_val));
    // }

    //
    // static void adjustContrast(ColorMatrix cm, int value)
    // {
    //     value = cleanValue(value, 100);
    //     if (value == 0) {
    //         return;
    //     }
    //     double x;
    //     if (value < 0) {
    //         x = (127 + ((value ~/ 100) * 127));
    //     } else {
    //         x = (value % 1);
    //         if (x == 0) {
    //             x = DELTA_INDEX[value];
    //         } else {
    //             x = ((DELTA_INDEX[value << 0] * (1 - x)) + (DELTA_INDEX[(value << 0) + 1] * x));
    //         }
    //         x = ((x * 127) + 127);
    //     }
    //     List<double> mat = new List<double>.from([x ~/ 127, 0, 0, 0, 0.5 * (127 - x), 0, x ~/ 127, 0, 0, 0.5 * (127 - x), 0, 0, x ~/ 127, 0, 0.5 * (127 - x), 0, 0, 0, 1, 0, 0, 0, 0, 0, 1]);
    //     cm.postConcat(new ColorMatrix(mat));
    // }
    //
    // static ColorFilter adjustColor(int brightness, int contrast, int saturation, int hue)
    // {
    //     ColorMatrix cm = new ColorMatrix();
    //     adjustHue(cm, hue);
    //     adjustContrast(cm, contrast);
    //     adjustBrightness(cm, brightness);
    //     adjustSaturation(cm, saturation);
    //     return new ColorMatrixColorFilter(cm);
    // }
}

