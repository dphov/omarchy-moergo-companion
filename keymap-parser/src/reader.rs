use std::fs;
use std::io;
use std::path::Path;

pub fn read_file<P: AsRef<Path>>(path: P) -> io::Result<String> {
    fs::read_to_string(path)
}

/// Remove C-style line and block comments, matching the original Python parser.
pub fn strip_comments(source: &str) -> String {
    let mut out = String::with_capacity(source.len());
    let bytes = source.as_bytes();
    let mut i = 0;
    let n = bytes.len();
    let mut slice_start = 0;
    let mut in_line_comment = false;
    let mut in_block_comment = false;

    while i < n {
        if !in_line_comment
            && !in_block_comment
            && i + 1 < n
            && bytes[i] == b'/'
            && bytes[i + 1] == b'/'
        {
            out.push_str(&source[slice_start..i]);
            in_line_comment = true;
            i += 2;
            continue;
        }
        if !in_line_comment
            && !in_block_comment
            && i + 1 < n
            && bytes[i] == b'/'
            && bytes[i + 1] == b'*'
        {
            out.push_str(&source[slice_start..i]);
            in_block_comment = true;
            i += 2;
            continue;
        }
        if in_line_comment && bytes[i] == b'\n' {
            in_line_comment = false;
            slice_start = i;
        }
        if in_block_comment && i + 1 < n && bytes[i] == b'*' && bytes[i + 1] == b'/' {
            in_block_comment = false;
            i += 2;
            slice_start = i;
            continue;
        }
        i += 1;
    }

    if !in_line_comment && !in_block_comment && slice_start < n {
        out.push_str(&source[slice_start..n]);
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_line_comments() {
        assert_eq!(strip_comments("a // comment\nb"), "a \nb");
    }

    #[test]
    fn strips_block_comments() {
        assert_eq!(strip_comments("a /* comment */ b"), "a  b");
    }

    #[test]
    fn strips_nested_looking_comments() {
        assert_eq!(strip_comments("/* a /* b */ c */"), " c */");
    }

    #[test]
    fn preserves_non_ascii_unicode() {
        assert_eq!(
            strip_comments("слой // комментарий\nкириллица /* блок */ ⌨️"),
            "слой \nкириллица  ⌨️"
        );
    }
}
