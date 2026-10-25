# Export the open project to recreate_project.tcl with repo-relative paths.
# Usage (Vivado Tcl console):
#   source -notrace [get_property DIRECTORY [current_project]]/../export_project.tcl

# Wrapped in apply to keep variables out of the console's global namespace.
apply {{} {
    set repo [file normalize [file dirname [info script]]]
    set script [file join $repo recreate_project.tcl]
    set prev_dir [pwd]

    cd $repo
    write_project_tcl -force -target_proj_dir build $script
    cd $prev_dir

    # write_project_tcl hardcodes absolute paths for BD module references;
    # rewrite every absolute repo path to $origin_dir.
    set f [open $script r]
    set s [read $f]
    close $f
    set s [string map [list "$repo/" {$origin_dir/}] $s]
    set f [open $script w]
    puts -nonewline $f $s
    close $f

    puts "Exported $script"
}}
