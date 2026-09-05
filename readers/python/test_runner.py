"""Test runner for Chapter 1 Gherkin feature files."""
import os
import sys
import re
from pathlib import Path

# Import the renderer module
import renderer


class ScenarioContext:
    """Context for a single scenario execution."""

    def __init__(self):
        self.variables = {}

    def set(self, name, value):
        """Set a variable in the context."""
        self.variables[name] = value

    def get(self, name):
        """Get a variable from the context."""
        return self.variables.get(name)


def parse_features(feature_file):
    """Parse a feature file and return list of scenarios."""
    with open(feature_file, 'r') as f:
        content = f.read()

    scenarios = []
    lines = content.split('\n')

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        if line.startswith('Scenario:') or line.startswith('Scenario Outline:'):
            # Parse scenario
            scenario_name = line.split(':', 1)[1].strip()
            is_outline = 'Outline' in line

            # Collect steps
            steps = []
            i += 1
            while i < len(lines):
                step_line = lines[i].strip()
                if not step_line or step_line.startswith('Feature:') or step_line.startswith('Scenario'):
                    break
                if step_line.startswith('Given') or step_line.startswith('When') or \
                   step_line.startswith('Then') or step_line.startswith('And'):
                    keyword = step_line.split()[0]
                    step_text = ' '.join(step_line.split()[1:])

                    # Handle multi-line steps with docstrings
                    docstring = None
                    if i + 1 < len(lines) and '"""' in lines[i + 1]:
                        i += 1
                        docstring_lines = []
                        # First line may have opening """
                        first_line = lines[i]
                        if first_line.strip().startswith('"""'):
                            first_line = first_line.strip()[3:]
                        else:
                            first_line = first_line.rstrip()
                        if first_line:
                            docstring_lines.append(first_line)

                        i += 1
                        while i < len(lines):
                            block_line = lines[i]
                            if '"""' in block_line:
                                # Closing quotes
                                before_quotes = block_line.split('"""')[0].rstrip()
                                if before_quotes:
                                    docstring_lines.append(before_quotes)
                                break
                            docstring_lines.append(block_line.rstrip())
                            i += 1

                        # Strip common leading whitespace from docstring
                        if docstring_lines:
                            # Find minimum indentation (ignoring empty lines)
                            non_empty_lines = [l for l in docstring_lines if l.strip()]
                            if non_empty_lines:
                                min_indent = min(len(l) - len(l.lstrip()) for l in non_empty_lines)
                                docstring_lines = [l[min_indent:] if len(l) > min_indent else l.lstrip() for l in docstring_lines]
                        docstring = '\n'.join(docstring_lines)

                    steps.append((keyword, step_text, docstring))
                i += 1
            i -= 1

            # Handle scenario outlines with examples
            examples = []
            if is_outline:
                # Look for Examples
                i += 1
                while i < len(lines):
                    line = lines[i].strip()
                    if line.startswith('Examples:'):
                        # Parse table
                        i += 1
                        headers = None
                        while i < len(lines):
                            table_line = lines[i].strip()
                            if not table_line or table_line.startswith('Scenario') or table_line.startswith('Feature'):
                                break
                            if table_line.startswith('|'):
                                cells = [c.strip() for c in table_line.split('|')[1:-1]]
                                if headers is None:
                                    headers = cells
                                else:
                                    example = dict(zip(headers, cells))
                                    examples.append(example)
                            i += 1
                        break
                    i += 1
                i -= 1
            else:
                examples = [{}]  # Single scenario with no examples

            for example in examples:
                scenarios.append({
                    'name': scenario_name,
                    'steps': steps,
                    'example': example
                })

        i += 1

    return scenarios


def expand_step(step_text, example):
    """Expand placeholders in step text with example values."""
    for key, value in example.items():
        step_text = step_text.replace(f'<{key}>', value)
    return step_text


def parse_comparison(text):
    """Parse a comparison like '1.0 = 1.0000001 ± 0.00001'."""
    # Try to match: a OP b [± tolerance]
    match = re.match(r'^(.*?)\s*(=|≠|=|!=)\s*(.*?)(?:\s*±\s*(.*))?$', text)
    if match:
        left = match.group(1).strip()
        op = match.group(2).strip()
        right = match.group(3).strip()
        tol_str = match.group(4).strip() if match.group(4) else None
        return left, op, right, tol_str
    return None


def evaluate_expression(expr_str, ctx):
    """Evaluate an expression given the context."""
    # Try to evaluate as a Python expression with context variables
    try:
        # Build namespace
        namespace = {
            'color': renderer.color,
            'canvas': renderer.canvas,
            'Color': renderer.Color,
            'Canvas': renderer.Canvas,
            'encode': renderer.encode,
            'decode': renderer.decode,
            'round': round,
            'write_pixel': renderer.write_pixel,
            'pixel_at': renderer.pixel_at,
            'fill': renderer.fill,
            'mix': renderer.mix,
            'canvas_to_ppm': renderer.canvas_to_ppm,
            'ppm_pixel': renderer.ppm_pixel,
            'max_channel_difference': renderer.max_channel_difference,
            'read_file': renderer.read_file,
            'distinct_values': renderer.distinct_values,
            'gray_match': renderer.gray_match,
            'quarter_match': renderer.quarter_match,
            'ramp': renderer.ramp,
            'clamp_pair': renderer.clamp_pair,
            'plate_01': renderer.plate_01,
        }
        namespace.update(ctx.variables)

        return eval(expr_str, namespace)
    except Exception as e:
        raise ValueError(f"Cannot evaluate '{expr_str}': {e}")


def compare_values(left_val, right_val, op, tolerance=0.0001):
    """Compare two values with the given operator and tolerance."""
    if op in ['=', '==']:
        if isinstance(left_val, renderer.Color) and isinstance(right_val, renderer.Color):
            return (abs(left_val.red - right_val.red) <= tolerance and
                    abs(left_val.green - right_val.green) <= tolerance and
                    abs(left_val.blue - right_val.blue) <= tolerance)
        elif isinstance(left_val, (int, float)) and isinstance(right_val, (int, float)):
            return abs(left_val - right_val) <= tolerance
        elif isinstance(left_val, tuple) and isinstance(right_val, tuple):
            # Compare tuples (pixel values)
            return all(abs(a - b) <= tolerance for a, b in zip(left_val, right_val))
        else:
            return left_val == right_val
    elif op in ['≠', '!=']:
        return not compare_values(left_val, right_val, '=', tolerance)
    elif op == '<':
        return left_val < right_val
    elif op == '<=':
        return left_val <= right_val
    elif op == '>':
        return left_val > right_val
    elif op == '>=':
        return left_val >= right_val
    return False


def execute_step(step_keyword, step_text, ctx, docstring=None):
    """Execute a single step and update context."""
    # Handle assignment: var ← expr
    if '←' in step_text:
        parts = step_text.split('←', 1)  # Split only on the first arrow
        var_name = parts[0].strip()
        expr = parts[1].strip()
        value = evaluate_expression(expr, ctx)
        ctx.set(var_name, value)
        return True, None

    # Handle procedure calls (statements that don't assign to a variable)
    # These are typically function calls with side effects
    if step_keyword in ['When', 'And'] and ('(' in step_text and ')' in step_text):
        # Check if it looks like a function call without assignment
        if '=' not in step_text and '←' not in step_text and '≠' not in step_text:
            try:
                evaluate_expression(step_text, ctx)
                return True, None
            except:
                pass  # Fall through to other handlers

    # Handle Given steps with "every pixel of c is color(...)"
    if step_text.startswith('every pixel of'):
        match = re.match(r'every pixel of (\w+) is color\((.*?)\)', step_text)
        if match:
            canvas_name = match.group(1)
            color_expr = f"color({match.group(2)})"
            expected_color = evaluate_expression(color_expr, ctx)
            canvas = ctx.get(canvas_name)
            for y in range(canvas.height):
                for x in range(canvas.width):
                    if canvas.pixels[y][x] != expected_color:
                        return False, f"Pixel at ({x}, {y}) is {canvas.pixels[y][x]}, expected {expected_color}"
            return True, None

    # Handle comparisons
    if any(op in step_text for op in ['=', '≠', '!=', '<', '<=', '>', '>=']):
        # Try to parse as a comparison
        comp = parse_comparison(step_text)
        if comp:
            left_str, op, right_str, tol_str = comp
            try:
                left_val = evaluate_expression(left_str, ctx)
                right_val = evaluate_expression(right_str, ctx)

                tolerance = 0.0001
                if tol_str:
                    tolerance = float(tol_str)

                if not compare_values(left_val, right_val, op, tolerance):
                    return False, f"{left_val} {op} {right_val} (tolerance {tolerance})"
                return True, None
            except Exception as e:
                return False, str(e)

    # Handle "linear blending is on/off"
    if 'linear blending is' in step_text:
        if 'on' in step_text:
            if not renderer.get_linear_blending():
                return False, "Linear blending is off, expected on"
            return True, None
        elif 'off' in step_text:
            renderer.set_linear_blending(False)
            return True, None

    # Handle "N pixels of c are color(...)"
    match = re.match(r'(\d+) pixels of (\w+) are color\((.*?)\)', step_text)
    if match:
        count = int(match.group(1))
        canvas_name = match.group(2)
        color_expr = f"color({match.group(3)})"
        expected_color = evaluate_expression(color_expr, ctx)
        canvas = ctx.get(canvas_name)
        actual_count = 0
        for y in range(canvas.height):
            for x in range(canvas.width):
                if canvas.pixels[y][x] == expected_color:
                    actual_count += 1
        if actual_count != count:
            return False, f"Found {actual_count} pixels of {expected_color}, expected {count}"
        return True, None

    # Handle "distinct_values(ppm) = N"
    match = re.match(r'distinct_values\((\w+)\)\s*=\s*(\d+)', step_text)
    if match:
        ppm_name = match.group(1)
        expected = int(match.group(2))
        ppm_text = ctx.get(ppm_name)
        actual = renderer.distinct_values(ppm_text)
        if actual != expected:
            return False, f"distinct_values returned {actual}, expected {expected}"
        return True, None

    # Handle "ppm_pixel(ppm, x, y) = (r, g, b) [± tolerance]"
    match = re.match(r'ppm_pixel\((\w+),\s*(\d+),\s*(\d+)\)\s*=\s*\((\d+),\s*(\d+),\s*(\d+)\)(?:\s*±\s*(\d+))?', step_text)
    if match:
        ppm_name = match.group(1)
        x = int(match.group(2))
        y = int(match.group(3))
        expected = (int(match.group(4)), int(match.group(5)), int(match.group(6)))
        tolerance = int(match.group(7)) if match.group(7) else 0
        ppm_text = ctx.get(ppm_name)
        actual = renderer.ppm_pixel(ppm_text, x, y)
        if not all(abs(a - e) <= tolerance for a, e in zip(actual, expected)):
            return False, f"ppm_pixel({x}, {y}) = {actual}, expected {expected} ± {tolerance}"
        return True, None

    # Handle "max_channel_difference(ppm1, ppm2) = N"
    match = re.match(r'max_channel_difference\((\w+),\s*(\w+)\)\s*([<>=≠!]+)\s*(\d+)', step_text)
    if match:
        ppm1_name = match.group(1)
        ppm2_name = match.group(2)
        op = match.group(3)
        expected = int(match.group(4))
        ppm1_text = ctx.get(ppm1_name)
        ppm2_text = ctx.get(ppm2_name)
        actual = renderer.max_channel_difference(ppm1_text, ppm2_text)
        if op == '=' and actual != expected:
            return False, f"max_channel_difference = {actual}, expected {expected}"
        elif op == '<=' and actual > expected:
            return False, f"max_channel_difference = {actual}, expected <= {expected}"
        elif op == '>=' and actual < expected:
            return False, f"max_channel_difference = {actual}, expected >= {expected}"
        return True, None

    # Handle "ppm ends with a newline character"
    if 'ppm ends with a newline character' in step_text:
        match = re.match(r'(\w+) ends with a newline character', step_text)
        if match:
            ppm_name = match.group(1)
            ppm_text = ctx.get(ppm_name)
            if not ppm_text.endswith('\n'):
                return False, "PPM does not end with newline"
            return True, None

    # Handle "lines N-M of ppm are ..." with docstring
    match = re.match(r'lines?\s+(\d+)(?:-(\d+))?\s+of\s+(\w+)\s+(?:is|are)', step_text)
    if match and docstring:
        start_line = int(match.group(1)) - 1  # Convert to 0-indexed
        end_line = int(match.group(2)) - 1 if match.group(2) else start_line
        ppm_name = match.group(3)
        ppm_text = ctx.get(ppm_name)
        ppm_lines = ppm_text.rstrip('\n').split('\n')

        # Expected lines from docstring
        expected_lines = docstring.rstrip('\n').split('\n')

        # Check if lines match
        for i, expected in enumerate(expected_lines):
            actual_line_idx = start_line + i
            if actual_line_idx >= len(ppm_lines):
                return False, f"Not enough lines in PPM (expected line {actual_line_idx + 1}, got {len(ppm_lines)})"
            actual = ppm_lines[actual_line_idx]
            if actual != expected:
                return False, f"Line {actual_line_idx + 1}: got '{actual}', expected '{expected}'"

        return True, None

    # Also check for "line N of ppm is ..." (single line)
    match = re.match(r'line\s+(\d+)\s+of\s+(\w+)\s+is\s+"(.+)"', step_text)
    if match:
        line_num = int(match.group(1)) - 1  # Convert to 0-indexed
        ppm_name = match.group(2)
        expected = match.group(3)
        ppm_text = ctx.get(ppm_name)
        ppm_lines = ppm_text.rstrip('\n').split('\n')
        if line_num >= len(ppm_lines):
            return False, f"Not enough lines in PPM (expected line {line_num + 1}, got {len(ppm_lines)})"
        actual = ppm_lines[line_num]
        if actual != expected:
            return False, f"Line {line_num + 1}: got '{actual}', expected '{expected}'"
        return True, None

    # Handle "every line of ppm is at most N characters"
    match = re.match(r'every line of\s+(\w+)\s+is\s+at most\s+(\d+)\s+characters', step_text)
    if match:
        ppm_name = match.group(1)
        max_len = int(match.group(2))
        ppm_text = ctx.get(ppm_name)
        for line in ppm_text.split('\n'):
            if len(line) > max_len:
                return False, f"Line too long: {len(line)} > {max_len}: {line}"
        return True, None

    return True, None


def run_scenario(scenario, feature_file):
    """Run a single scenario."""
    ctx = ScenarioContext()
    # Ensure linear blending is on for each scenario
    renderer.set_linear_blending(True)

    scenario_name = scenario['name']
    example = scenario['example']

    for step_tuple in scenario['steps']:
        if len(step_tuple) == 3:
            keyword, step_text, docstring = step_tuple
        else:
            keyword, step_text = step_tuple
            docstring = None

        # Expand step with example values
        step_text = expand_step(step_text, example)

        success, error = execute_step(keyword, step_text, ctx, docstring)

        if not success:
            return False, error

    return True, None


def run_all_scenarios(feature_dir):
    """Run all scenarios in all feature files."""
    feature_files = sorted(Path(feature_dir).glob('*.feature'))

    total = 0
    passed = 0
    failed = 0
    failures = []

    for feature_file in feature_files:
        print(f"\n{feature_file.name}:")
        scenarios = parse_features(str(feature_file))

        for scenario in scenarios:
            total += 1
            success, error = run_scenario(scenario, feature_file)

            if success:
                passed += 1
                print(f"  ✓ {scenario['name']}")
            else:
                failed += 1
                print(f"  ✗ {scenario['name']}")
                if error:
                    print(f"    Error: {error}")
                failures.append((feature_file.name, scenario['name'], error))

    print(f"\n{'='*60}")
    print(f"Total: {total}, Passed: {passed}, Failed: {failed}")
    if failures:
        print(f"\nFailures:")
        for filename, scenario, error in failures:
            print(f"  {filename}: {scenario}")
            if error:
                print(f"    {error}")

    return total, passed, failed, failures


if __name__ == '__main__':
    feature_dir = os.path.join(os.path.dirname(__file__), 'features')
    total, passed, failed, failures = run_all_scenarios(feature_dir)
    sys.exit(0 if failed == 0 else 1)
