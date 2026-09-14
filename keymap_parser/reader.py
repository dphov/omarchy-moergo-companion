def read_file(path: str) -> str:
    """Read a keymap file into memory."""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def strip_comments(source: str) -> str:
    """Remove C-style line and block comments, matching the original C parser."""
    out: list[str] = []
    i = 0
    n = len(source)
    in_line_comment = False
    in_block_comment = False

    while i < n:
        if not in_line_comment and not in_block_comment and source[i : i + 2] == "//":
            in_line_comment = True
            i += 2
            continue
        if not in_line_comment and not in_block_comment and source[i : i + 2] == "/*":
            in_block_comment = True
            i += 2
            continue
        if in_line_comment and source[i] == "\n":
            in_line_comment = False
        if in_block_comment and source[i : i + 2] == "*/":
            in_block_comment = False
            i += 2
            continue
        if not in_line_comment and not in_block_comment:
            out.append(source[i])
        i += 1

    return "".join(out)
