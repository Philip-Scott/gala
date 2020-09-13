


/**
    Holder {
        Leaf 1: Leaf
        Leaf 2: Leaf

        Window: The reference to this window. Window is null if has any leafs
        Split: Number // Distance between the split
        Orientation: Horizontal | Vertical
    }
 */ 
 
public enum NodeOrientation {
    HORIZONTAL,
    VERTICAL
}

const int MARGIN = 4;

public class Gala.Plugins.Tiles.Forest.Node {
    public unowned Meta.Window? window = null;
    public NodeOrientation orientation = NodeOrientation.HORIZONTAL;

    private bool last_added_left = false;

    public Node? leaf_right = null;
    public Node? leaf_left = null;

    private Meta.Rectangle rectangle;

    private uint split = 0;

    public Node (unowned Meta.Window _window, NodeOrientation _orientation, Meta.Rectangle _rectangle) {
        window = _window;
        orientation = _orientation;

        rectangle = _rectangle;
    }

    /** 
        Attaches a window to the tree.

        return: the node of the attached window.
    */
    public Node attach_window (unowned Meta.Window new_window) {
        if (this.window != null) {
            var new_orientation = orientation == NodeOrientation.HORIZONTAL ? NodeOrientation.VERTICAL : NodeOrientation.HORIZONTAL;

            this.leaf_left = new Node (this.window, new_orientation, get_rectangle_division (false, new_orientation));
            this.leaf_right = new Node (new_window, new_orientation, get_rectangle_division (true, new_orientation));

            this.window = null;

            return leaf_right;
        } else if (last_added_left) {
            last_added_left = false;
            return leaf_right.attach_window (new_window);
        } else {
            last_added_left = true;
            return leaf_left.attach_window (new_window);
        }
    } 

     /** 
        Attaches a window to the tree at a coordinate
        return: the node of the attached window.
    */
    public Node attach_window_at (unowned Meta.Window new_window, int x, int y, NodeOrientation previous_orientation) {
        if (this.window != null) {
            var new_orientation = previous_orientation == NodeOrientation.HORIZONTAL ? NodeOrientation.VERTICAL : NodeOrientation.HORIZONTAL;
            
            var rectangle_left = get_rectangle_division (false, new_orientation);
            var rectangle_right = get_rectangle_division (true, new_orientation);

            if (point_in_rectangle(x, y, rectangle_left)) {
                this.leaf_left = new Node (new_window, new_orientation, rectangle_left);
                this.leaf_right = new Node (this.window, new_orientation, rectangle_right);

                this.window = null;
                return leaf_left;
            } else {
                this.leaf_left = new Node (this.window, new_orientation, rectangle_left);
                this.leaf_right = new Node (new_window, new_orientation, rectangle_right);

                this.window = null;
                return leaf_right;
            }
        } else {
            if (point_in_rectangle(x, y, this.leaf_left.rectangle)) {
                return this.leaf_left.attach_window_at(new_window, x, y, this.orientation);
            } else {
                return this.leaf_right.attach_window_at(new_window, x, y, this.orientation);
            }
        }
    }

    private bool point_in_rectangle (int x, int y, Meta.Rectangle rectangle) {
        string rectangle_string = "%dx%d : %d,%d".printf (rectangle.width, rectangle.height, rectangle.x, rectangle.y);

        var condition = rectangle.x <= x <= rectangle.x + rectangle.width && rectangle.y <= y <= rectangle.y + rectangle.height;
        if (condition) {
            stderr.printf("%s contains %d %d\n", rectangle_string, x, y);
        } else {
            stderr.printf("%s not contains %d %d\n", rectangle_string, x, y);
        }

        return condition;
    }

    /** 
        Attaches a window to the tree.

        return: the new root, or null if window was removed from this node
    */
    public Node? remove_window (unowned Meta.Window window_to_remove) {
        if (this.window != null) {
            if (this.window.get_id () == window_to_remove.get_id()) {
                return null;
            } else {
                return this;
            }
        } else {
            this.leaf_left = this.leaf_left.remove_window (window_to_remove);
            this.leaf_right = this.leaf_right.remove_window (window_to_remove);
            
            if (this.leaf_left == null && this.leaf_right != null) {
                this.leaf_right.pass_rectangle (this.rectangle.copy());
                return this.leaf_right;
            } else if (this.leaf_left != null && this.leaf_right == null) {
                this.leaf_left.pass_rectangle (this.rectangle.copy());
                return this.leaf_left;
            } else if (this.leaf_left == null && this.leaf_right == null) {
                return null;
            } else {
                this.leaf_right.pass_rectangle (get_rectangle_division (true, orientation));
                this.leaf_left.pass_rectangle (get_rectangle_division (false, orientation));
                return this;
            }
        }
    }

    public void reflow () {
        if (window != null) {
            var new_pos = rectangle.copy ();
            new_pos.height = new_pos.height - MARGIN * 2;
            new_pos.width = new_pos.width - MARGIN * 2;
            new_pos.y = new_pos.y + MARGIN;
            new_pos.x = new_pos.x + MARGIN;
            window.move_resize_frame (false, new_pos.x, new_pos.y, new_pos.width, new_pos.height);
        } else {
            leaf_left.reflow ();
            leaf_right.reflow ();
        }
    }

    public void pass_rectangle (Meta.Rectangle new_rectangle) {
        this.rectangle = new_rectangle;

        if (window == null) {
            this.leaf_right.pass_rectangle (get_rectangle_division (true, orientation));
            this.leaf_left.pass_rectangle (get_rectangle_division (false, orientation));
        }
    }

    private Meta.Rectangle get_rectangle_division (bool right_side, NodeOrientation _orientation) {
        var new_rectangle = this.rectangle.copy();

        if (_orientation == NodeOrientation.HORIZONTAL) {
            new_rectangle.width = new_rectangle.width / 2;

            if (right_side) {
                new_rectangle.x = new_rectangle.x + new_rectangle.width;
            }
        } else {
            new_rectangle.height = new_rectangle.height / 2;

            if (right_side) {
                new_rectangle.y = new_rectangle.y + new_rectangle.height;
            }
        }


        return new_rectangle;
    }

    public string to_string () {
        return "%dx%d : %d,%d %s".printf (rectangle.width, rectangle.height, rectangle.x, rectangle.y, window != null ? window.get_title() : "()");
    }

    public void print (string depth) {
        if (window != null) {
            stderr.printf ("-%s : %s\n", depth, this.to_string ());
        } else {
            stderr.printf ("-%s : %s\n", depth, this.to_string ());

            leaf_left.print(depth + "-");
            leaf_right.print(depth + "-");
        }
    }
}