

public class Gala.Plugins.Tiles.WorkspaceController {

    public WorkspaceController (Meta.WorkspaceManager workspace_manager) {
        workspace_manager.workspace_added.connect ((added_id) => {
            stderr.printf ("Workspace added\n");

            var workspace = workspace_manager.get_workspaces ().nth_data(added_id);
            workspace.window_added.connect (on_window_added);
            workspace.window_removed.connect (on_window_removed);
        });

        workspace_manager.workspace_removed.connect ((added_id) => {
            stderr.printf ("Workspace removed\n");
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
        });

        workspace_manager.workspaces_reordered.connect (() => {
            stderr.printf ("Workspace reordered\n");
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
        });
    }

    public void on_window_added (Meta.Window window) {
        var id = window.get_id ();

        if (tracked_windows.contains (id) || !handle_window(window)) return;
        stdout.printf (@"Adding Window: \n");
        add_window_to_workspace_tree (window);

        var workspace = window.get_workspace ();
        if (workspace_roots.has_key (workspace.index ())) {
            var root = workspace_roots.get (workspace.index ());
            root.reflow ();
        }
    } 

    public void on_window_removed (Meta.Window window) {
        var id = window.get_id ();
        if (!tracked_windows.contains (id)) return;
        
        stdout.printf (@"Removing window: \n");
        remove_window_from_workspace_tree (window);
    }
}