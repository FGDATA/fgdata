# Minimalistic framework for automated testing in Nasal
#
# Copyright (C) 2014 Anton Gomez Alvedro
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.


# TestSuite
#
# Tests are organized in test suites. Each test suite contains an arbitrary
# number of tests, and two special methods "setup" and "cleanup". Setup is
# called before every test, and cleanup is called after every test.
#
# In order to define a test suite, you have to create an object parented to
# TestSuite. The testing framework will identify any method in your object whose
# name starts with "test_" as a test case to be run.
#
# Important: The order in which test cases and test suites are executed
# is undefined!
#
# Example:
#
# var MyTestSuite = {
#
#	parents: [TestSuite],
#
#	setup: func {
#		Stuff to do before every test...
#		This is optional. You don't need to provide it if you don't use it.
#	},
#
#	cleanup: func {
#		Stuff to do after every test...
#		Also optional.
#	},
#
#	my_auxiliary_function: func {
#		Methods that do not start with "test_" will not be executed by the
#		test runner. You can define as many auxiliary functions in the test
#		suite as you wish.
#	},
#
#	test_trivial_test: func {
#		This is a real test (starts with "test_"), and it will be run by the
#	    framework when test_run() is called.#
#	}
# };

var TestSuite = {
	setup: func 0,
	cleanup: func 0
};

# run_tests([namespace])
#
# Executes all test suites found in the given namespace. If no namespace is
# specified, then the namespace where run_tests is defined is used by default.
#
# An effective way to work with the framework is to just include the framework
# from your test files:
#
#	io.include(".../test.nas");
#
# and then execute a script like this in the Nasal Console:
#
#	delete(globals, "test");
#	io.load_nasal(".../my_test_suite.nas", "test");
#	test.run_tests();
#
# What this script does is: it empties the "test" namespace and then loads your
# script into that namespace. The test framework will be loaded in there as
# well if it was io.include'd in my_test_suite.nas. Finally, all test suites
# in the "test" namespace are executed.

var run_tests = func(namespace=nil) {

	var ns = namespace != nil ? namespace : closure(run_tests, 1);

	var passed = 0;
	var failed = 0;
	var err = [];

	foreach(var suite_name; keys(ns)) {
		var suite = ns[suite_name];

		if (!isa(suite, TestSuite))
			continue;

		print("Running test suite ", suite_name);

		foreach (var test_name; keys(suite)) {

			if (find("test_", test_name) != 0)
				continue;

			# Run the test case
			setsize(err, 0);
			contains(suite, "setup") and call(suite.setup, [], suite, err);
			size(err) == 0 and call(suite[test_name], [], suite, err);
			size(err) == 0 and contains(suite, "cleanup") and call(suite.cleanup, [], suite, err);

			if (size(err) == 0) {
				passed += 1;
				continue;
			}

			failed += 1;
			print("Test ", test_name, " FAILED\n");
			debug.printerror(err);
		}
	}

	print(sprintf("\n%d tests run. %d passed, %d failed",
	              passed + failed, passed, failed));
}


var assert_prop_exists = func (prop) {
	assert(props.globals.getNode(prop) != nil,
	       sprintf("Property %s does not exist", prop));
}


var fail_if_prop_exists = func (prop) {
	assert(props.globals.getNode(prop) == nil,
	       sprintf("Property %s exists", prop));
}
