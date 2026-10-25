foreach cmd {add_file add_design save_project save_project_as close_project open_project} {
    puts "COMMAND $cmd [info commands $cmd]"
    catch {help $cmd} result
    puts $result
}
exit 0
