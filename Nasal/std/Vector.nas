# Copyright (C) 2014  onox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

var min = func(a, b) { a < b ? a : b }
var max = func(a, b) { a > b ? a : b }

var Vector = {

    new: func (vector=nil) {
        var m = {
            parents: [Vector]
        };
        if (vector == nil) {
            vector = [];
        }
        m.vector = vector;
        return m;
    },

    size: func {
        # Return the number of items in the vector

        return size(me.vector);
    },

    clear: func {
        # Remove all items from the vector, resulting in an empty vector

        me.vector = [];
    },

    append: func (item) {
        # Append the given item at the end of the vector

        append(me.vector, item);
    },

    extend: func (other_vector) {
        # Extend the vector with another vector, appending the items of
        # the other vector to this vector

        me.vector = me.vector ~ other_vector;
    },

    insert: func (index, item) {
        # Insert the given item at the given index before the old item
        # at that index. Any index greater than n-1 where n is the size of
        # the vector will append the given item at the end. Any index smaller
        # or equal to -n will insert the item at the beginning of the vector.
        #
        # For example, if the vector contains ["a", "b", "c"], then the
        # following operations can happen:
        #
        # insert(0, "d")  => ["d", "a", "b", "c"]
        # insert(2, "e")  => ["a", "b", "e", "c"]
        # insert(3, "f")  => ["a", "b", "c", "f"]
        # insert(-3, "g") => ["f", "a", "b", "c"]

        index = min(index, me.size());
        if (index < 0) {
            index = max(0, me.size() + index);
        }
        me.vector = subvec(me.vector, 0, index) ~ [item] ~ subvec(me.vector, index);
    },

    pop: func (index=nil) {
        # Remove and return the item at the given index. If index
        # is not given, then it will remove and return the last item.
        # A negative index represents the position from the end.
        #
        # For example, if the vector contains ["a", "b", "c"], then the
        # following operations can happen:
        #
        # pop(0)  => "a"
        # pop(2)  => "c"
        # pop(-1) => "c"
        # pop(-3) => "a"
        #
        # Thus the range is -n .. n-1 where n is the size of the vector.
        # IndexError is raised if the index is out of range.

        if (index != nil) {
            if (index < -me.size() or index >= me.size()) {
                die("IndexError: index out of range");
            }

            if (index < 0) {
                index = me.size() + index;
            }
            var item = me.vector[index];
            me.vector = subvec(me.vector, 0, index) ~ subvec(me.vector, index + 1);
            return item;
        }
        else {
            return pop(me.vector);
        }
    },

    index: func (item) {
        # Return first index of the given item. Raises a ValueError
        # if the item is not in the vector.

        forindex (var index; me.vector) {
            if (me.vector[index] == item) {
                return index;
            }
        };
        die("ValueError: item not in the vector");
    },

    contains: func (item) {
        # Return true if the vector contains the item, false otherwise

        var err = [];
        call(Vector.index, [item], me, err);

        return size(err) == 0;
    },

    remove: func (item) {
        # Remove the first occurrence of the given item. Raises a
        # ValueError if the item is not present in the vector.

        me.pop(me.index(item));
    }
    
};
