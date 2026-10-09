"""Git clean filter: strip outputs from Jupyter notebooks before they are committed.

Notebook outputs can contain individual survey responses (e.g. ``df.head()``), and the
ÍSKOS microdata must not be published. With this filter the committed notebooks hold code
and narration only, while your local copies keep their outputs.

Set up once per clone (``required`` makes a commit fail rather than skip the filter):

    git config filter.nbstrip.clean "python3 scripts/strip_notebook_outputs.py"
    git config filter.nbstrip.smudge cat
    git config filter.nbstrip.required true

``.gitattributes`` applies the filter to every ``*.ipynb``. Reads a notebook on stdin and
writes the stripped notebook to stdout; uses only the standard library.
"""
import json
import sys


def strip(nb: dict) -> dict:
    for cell in nb.get("cells", []):
        if cell.get("cell_type") == "code":
            cell["outputs"] = []
            cell["execution_count"] = None
        # nbconvert/jupyter add per-run bookkeeping; it changes on every execution.
        meta = cell.get("metadata", {})
        for key in ("execution", "collapsed", "scrolled"):
            meta.pop(key, None)
    return nb


def main() -> None:
    raw = sys.stdin.read()
    try:
        nb = json.loads(raw)
    except json.JSONDecodeError:
        sys.stdout.write(raw)   # not a notebook we understand: pass through unchanged
        return
    json.dump(strip(nb), sys.stdout, indent=1, ensure_ascii=False, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
