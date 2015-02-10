var abs = func(n) { n < 0 ? -n : n }

var sgn = func(x) { x < 0 ? -1 : x > 0 }

var max = func(x) {
    var n = x;
    for (var i = 0; i < size(arg); i += 1) {
        if (arg[i] > n) n = arg[i];
    }
    return n;
}

var min = func(x) {
    var n = x;
    for (var i = 0; i < size(arg); i += 1) {
        if (arg[i] < n) n = arg[i];
    }
    return n;
}

var avg = func {
    var x = 0;
    for (var i = 0; i < size(arg); i += 1) {
        x += arg[i];
    }
    x /= size(arg);
    return x;
}

# note - mathlib defines an fmod function (added after this was written)
# It uses C-library fmod(), which has different rounding behaviour to
# this code (eg, fmod(-5, 4) gives -1, whereas this code gives 3)
var mod = func(n, m) {
    var x = n - m * int(n/m);      # int() truncates to zero, not -Inf
    return x < 0 ? x + abs(m) : x; # ...so must handle negative n's
}

var _iln10 = 1/ln(10);
var log10 = func(x) { ln(x) * _iln10 }
