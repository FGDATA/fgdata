var bit = [var _ = 1];
for (var i = 1; i < 32; i += 1)
	append(bit, _ += _);


# checks whether bit <b> is set in number <n>
var test = func(n, b) {
	n /= bit[b];
	return int(n) != int(n / 2) * 2;
}


# returns number <n> with bit <b> set
var set = func(n, b) n + !test(n, b) * bit[b];


# returns number <n> with bit <b> cleared
var clear = func(n, b) n - test(n, b) * bit[b];


# returns number <n> with bit <b> toggled
var toggle = func(n, b) test(n, b) ? n - bit[b] : n + bit[b];


# returns number <n> with bit <b> set to value <v>
var switch = func(n, b, v) n - (test(n, b) - !!v) * bit[b];


# returns number <n> as bit string, zero-padded to <len> digits:
#   bits.string(6)     ->       "110"
#   bits.string(6, 8)  ->  "00000110"
var string = func(n, len = 1) {
	var s = "";
	while (n) {
		var v = int(n / 2);
		s = (v + v != n) ~ s;
		n = v;
	}
	for (var i = size(s); i < len; i += 1)
		s = '0' ~ s;
	return s;
}


# returns bit string <s> as number:  bits.value("110")  ->  6
var value = func(s) {
	var n = 0;
	var len = size(s);
	for (var i = 0; i < len; i += 1)
		n += n + (s[i] != `0`);
	return n;
}


