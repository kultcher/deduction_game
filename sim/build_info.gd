## Which code a case ran on, for dev logs (case_start "build"), so a replay can check out the
## same commit. Reads the project's git metadata directly (no subprocess); "" outside a git
## checkout, e.g. in an exported build.
extends RefCounted

static var _commit: String = ""
static var _read: bool = false

static func commit() -> String:
	if _read:
		return _commit
	_read = true
	var git_dir: String = ProjectSettings.globalize_path("res://.git")
	if FileAccess.file_exists(git_dir):
		# A worktree: .git is a file naming the real git dir.
		var line: String = FileAccess.get_file_as_string(git_dir).strip_edges()
		if not line.begins_with("gitdir:"):
			return _commit
		git_dir = line.trim_prefix("gitdir:").strip_edges()
		if git_dir.is_relative_path():
			git_dir = ProjectSettings.globalize_path("res://").path_join(git_dir)
	if not FileAccess.file_exists(git_dir.path_join("HEAD")):
		return _commit
	var head: String = FileAccess.get_file_as_string(git_dir.path_join("HEAD")).strip_edges()
	if not head.begins_with("ref:"):
		_commit = head
		return _commit
	var ref: String = head.trim_prefix("ref:").strip_edges()
	var common: String = git_dir
	if FileAccess.file_exists(git_dir.path_join("commondir")):
		common = git_dir.path_join(FileAccess.get_file_as_string(git_dir.path_join("commondir")).strip_edges()).simplify_path()
	for base in [git_dir, common]:
		if FileAccess.file_exists(base.path_join(ref)):
			_commit = FileAccess.get_file_as_string(base.path_join(ref)).strip_edges()
			return _commit
	var packed: String = common.path_join("packed-refs")
	if FileAccess.file_exists(packed):
		for l in FileAccess.get_file_as_string(packed).split("\n"):
			if l.ends_with(" " + ref):
				_commit = l.get_slice(" ", 0)
				break
	return _commit
