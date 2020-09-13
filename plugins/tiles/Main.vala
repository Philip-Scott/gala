//
//  Copyright (C) 2020 Felipe Escoto
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

/*
Forest composed of:

List<Trees> // One tree per workspace and display.

Leaf: Holder | Window

Holder {
    Leaf 1: Leaf
    Leaf 2: Leaf
    Split: Number // Distance between the split
    Orientation: Horizontal | Vertical
}

Rules:
- Always on top windows are always floating.
- skip_taskbar == window floating

*/

public class Gala.Plugins.Tiles.Plugin : Gala.Plugin {
    private Gala.WindowManager? wm = null;

    Gee.HashMap<uint, Forest.Node> workspace_roots = new Gee.HashMap<uint, Forest.Node> ();
    Gee.TreeSet<uint64?> windows_on_forest = new Gee.TreeSet<uint64?> ((a, b) => {
        if (a > b) return 1;
        if (a < b) return -1;
        return 0;
    });

    Gee.TreeSet<uint64?> tracked_windows = new Gee.TreeSet<uint64?> ((a, b) => {
        if (a > b) return 1;
        if (a < b) return -1;
        return 0;
    });
    
    bool initialized = false;

    construct {}

    public override void initialize (Gala.WindowManager wm) {
        stdout.printf ("Tiler enabled\n");
        this.wm = wm;
#if HAS_MUTTER330
        var display = wm.get_display ();
#else
        var display = wm.get_screen ().get_display ();
#endif
        var settings = new GLib.Settings (Config.SCHEMA + ".keybindings");
        display.add_keybinding ("tiles", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
        display.add_keybinding ("print-tiles", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) print_tiles);
    }
    
    [CCode (instance_pos = -1)]
    void on_initiate (Meta.Display _display, Meta.Window? _window, Clutter.KeyEvent event, Meta.KeyBinding binding) {
        if (initialized) return;
        initialized = true;

        var display = wm.get_display ();
        var workspace_manager = display.get_workspace_manager ();

        unowned List<Meta.Workspace> workspaces = workspace_manager.get_workspaces ();

        foreach (var workspace in workspaces) {
            workspace.window_added.connect (on_window_added);
            workspace.window_removed.connect (on_window_removed);

            List<weak Meta.Window> windows = workspace.list_windows ();
            foreach (var window in windows) {
               on_window_added (window);
            }
            
            if (workspace_roots.has_key (workspace.index ())) {
                var root = workspace_roots.get (workspace.index ());
                root.reflow ();
            }
        }

        display.grab_op_end.connect ((disp, window, op) => {
            switch (op) {
                case Meta.GrabOp.MOVING:
                stderr.printf("Handle moved window\n");
                break;
                case Meta.GrabOp.RESIZING_E: 
                case Meta.GrabOp.RESIZING_N: 
                case Meta.GrabOp.RESIZING_NE: 
                case Meta.GrabOp.RESIZING_NW: 
                case Meta.GrabOp.RESIZING_S: 
                case Meta.GrabOp.RESIZING_SE: 
                case Meta.GrabOp.RESIZING_SW: 
                case Meta.GrabOp.RESIZING_W: 
                stderr.printf("Handle Resizing\n");
                break;
            }
        });

        // Manage new workspaces
        workspace_manager.workspace_added.connect ((added_id) => {
            var workspace = workspace_manager.get_workspaces ().nth_data(added_id);
            workspace.window_added.connect (on_window_added);
            workspace.window_removed.connect (on_window_removed);
        });

        workspace_manager.workspace_removed.connect ((removed_id) => {
            recalculate_roots ();
        });

        workspace_manager.workspaces_reordered.connect (() => {
            recalculate_roots ();
        });
    }

    private void recalculate_roots () {
        var roots_reordered = new Gee.HashMap<uint, Forest.Node> ();

        foreach (var root in this.workspace_roots) {
            Forest.Node? node = root.value;

            while (node != null && node.window == null) {
                node = node.leaf_left;
            }

            if (node != null) {
                var index = node.window.get_workspace().index ();
                roots_reordered.set (index, root.value);
            }
        }

        this.workspace_roots.clear ();
        this.workspace_roots = roots_reordered;
    }

    private void add_window_to_workspace_tree (Meta.Window window) {
        var window_id = window.get_id ();
        if (windows_on_forest.contains (window_id)) return;
        
        var monitor = window.get_monitor ();
        var workspace = window.get_workspace ();
        var display = wm.get_display ();
        
        // TODO: Handle multi-monitors
        if (monitor == 0) {
            if (!workspace_roots.has_key (workspace.index ())) {
                var rectangle = display.get_monitor_geometry (monitor);

                // Wingpanel. TODO: Get rectangles from screen
                rectangle.height = rectangle.height - 24; 
                rectangle.y = rectangle.y + 24;

                var node = new Forest.Node (window, NodeOrientation.HORIZONTAL, rectangle);
                windows_on_forest.add (window_id);
                workspace_roots.set (workspace.index (), node);

                connect_window_signals (window);
            } else {
                var root = workspace_roots.get (workspace.index ());
                root.attach_window (window);
                
                windows_on_forest.add (window_id);
                connect_window_signals (window);
            }
        }
    }

    private void remove_window_from_workspace_tree (Meta.Window window) { 
        var workspace_index = window.get_workspace ().index ();

        var currentRoot = this.workspace_roots.get (workspace_index);
        if (currentRoot != null) {
            var newRoot = currentRoot.remove_window (window);
            
            if (newRoot != null) {
                newRoot.reflow ();
            }
            
            this.workspace_roots.set (workspace_index, newRoot);
        }

        this.windows_on_forest.remove(window.get_id ());
    }

    public void on_window_added (Meta.Window window) {
        var id = window.get_id ();

        if (tracked_windows.contains (id)) return;

        if (handle_window(window)) {
            add_window_to_workspace_tree (window);
            reflow_tree_from_window(window);
        }

        window.notify.connect(window_notify);

        tracked_windows.add(id);
    } 

    public void window_notify (Object object, ParamSpec pspec) {
        var window = (Meta.Window) object;

        switch (pspec.name) {
            case "above":
            case "fullscreen":
            case "maximized-horizontally":
            case "maximized-vertically":
            case "minimized":
            case "on-all-workspaces":
                var window_id = window.get_id ();
                if (this.windows_on_forest.contains (window_id) && !handle_window(window)) {
                    remove_window_from_workspace_tree (window);
                    reflow_tree_from_window(window);
                }

                if (!this.windows_on_forest.contains (window_id) && handle_window(window)) {
                    add_window_to_workspace_tree (window);
                    reflow_tree_from_window(window);
                }
            break;
        }

        
    } 

    public void reflow_tree_from_window (Meta.Window window) {
        var workspace = window.get_workspace ();
        if (workspace_roots.has_key (workspace.index ())) {
            var root = workspace_roots.get (workspace.index ());
            root.reflow ();
        }
    }

    public void on_window_removed (Meta.Window window) {
        stdout.printf (@"Removing window: \n");
        var id = window.get_id ();

        if (this.tracked_windows.contains(id)) {
            this.tracked_windows.remove(id);
            window.notify.disconnect(window_notify);

            if (this.windows_on_forest.contains (id)) {
                remove_window_from_workspace_tree (window);
            }
        }
    }

    /*
        Checks window against list of contitions to see if we should track it or not on the tree
    */
    private bool handle_window (Meta.Window window) {
        return 
            !window.skip_taskbar && 
            window.allows_resize () && 
            window.allows_move () &&
            !window.is_fullscreen () &&
            !window.is_hidden () && 
            !window.maximized_horizontally &&
            !window.maximized_vertically &&
            !window.minimized &&
            !window.above
        ;
    }

    [CCode (instance_pos = -1)]
    void print_tiles (Meta.Display _display, Meta.Window? _window, Clutter.KeyEvent event, Meta.KeyBinding binding) {
        foreach (var root in workspace_roots) {
            root.value.print("");
        }
    }

    public void connect_window_signals (Meta.Window window) {
        window.unmanaging.connect (() => {
            remove_window_from_workspace_tree(window);
        });
    } 

    public void remove_window_from_forest (Meta.Window window) {
        stdout.printf (@"Reflow all\n");

        foreach (var root in workspace_roots) {
            root.value.reflow();
            root.value.print("");
        }
    }


    public void reflow_all () {
        stdout.printf (@"Reflow all\n");

        foreach (var root in workspace_roots) {
            root.value.reflow();
            root.value.print("");
        }
    }

    public override void destroy () {
        unowned Meta.Display display = wm.get_display ();
        unowned List<Meta.WindowActor> actors = display.get_window_actors ();
    }
}

public Gala.PluginInfo register_plugin () {
    return Gala.PluginInfo () {
        name = "Auto Tiling",
        author = "Felipe Escoto <felescoto95@hotmail.com>",
        plugin_type = typeof (Gala.Plugins.Tiles.Plugin),
        provides = Gala.PluginFunction.ADDITION,
        load_priority = Gala.LoadPriority.IMMEDIATE
    };
}
