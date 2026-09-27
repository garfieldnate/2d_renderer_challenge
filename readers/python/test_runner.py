"""Test runner for Chapter 1 Gherkin feature files."""
import os
import sys
import re
import math
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
                    # Split only on the first run of whitespace, so a
                    # string literal later in the step (e.g. "  two
                    # spaces ") keeps its internal spacing exactly --
                    # collapsing it with a naive split()/' '.join() was
                    # corrupting any scenario that pins whitespace inside
                    # a quoted string (chapter 19's itemize scenarios do).
                    parts = step_line.split(None, 1)
                    keyword = parts[0]
                    step_text = parts[1] if len(parts) > 1 else ""

                    # Handle multi-line steps with docstrings or tables
                    docstring = None
                    if i + 1 < len(lines):
                        next_line = lines[i + 1].strip()
                        if '"""' in next_line:
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
                        elif next_line.startswith('|'):
                            # Handle Gherkin table
                            table_lines = []
                            i += 1
                            while i < len(lines):
                                table_line = lines[i].strip()
                                if not table_line.startswith('|'):
                                    break
                                table_lines.append(table_line)
                                i += 1
                            i -= 1  # Back up one since the outer loop will increment
                            docstring = '\n'.join(table_lines)

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
    """Parse a comparison like '1.0 = 1.0000001 ± 0.00001'.

    Scans character by character rather than with a plain regex, tracking
    quotes and bracket depth, because chapter 20's scenarios embed raw XML
    text (with its own '=' signs inside quoted attribute values, e.g.
    parse_xml("<rect width='10' .../>")) directly in a comparison step. A
    naive regex's non-greedy left group happily matches the FIRST '=' it
    finds -- including one inside a quoted string -- which corrupts the
    split. Only a '=' (or another comparison operator, or the tolerance
    marker '±') seen outside any quote and at bracket depth 0 is the real
    one."""
    n = len(text)
    i = 0
    depth = 0
    quote = None
    tokens = []  # (start, end, token) for operators/tolerance found at top level
    while i < n:
        ch = text[i]
        if quote:
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ('"', "'"):
            quote = ch
            i += 1
            continue
        if ch in '([{':
            depth += 1
            i += 1
            continue
        if ch in ')]}':
            depth -= 1
            i += 1
            continue
        if depth == 0:
            two = text[i:i + 2]
            if two in ('!=', '<=', '>='):
                tokens.append((i, i + 2, two))
                i += 2
                continue
            if ch in '≤≥≠=<>':
                tokens.append((i, i + 1, ch))
                i += 1
                continue
            if ch == '±':
                tokens.append((i, i + 1, '±'))
                i += 1
                continue
        i += 1

    if not tokens:
        return None

    op_start, op_end, op = tokens[0]
    left = text[:op_start].strip()
    tol_str = None
    right = text[op_end:].strip()
    for (s, e, tk) in tokens[1:]:
        if tk == '±':
            right = text[op_end:s].strip()
            tol_str = text[e:].strip()
            break
    return left, op, right, tol_str


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
            'round': renderer.round_half_up,
            'length': len,
            'true': True,
            'false': False,
            'True': True,
            'False': False,
            'none': None,
            'None': None,
            'write_pixel': renderer.write_pixel,
            'pixel_at': renderer.pixel_at,
            'fill': renderer.fill,
            'mix': renderer.mix,
            'canvas_to_ppm': renderer.canvas_to_ppm,
            'canvas_to_p6': renderer.canvas_to_p6,
            'ppm_pixel': renderer.ppm_pixel,
            'max_channel_difference': renderer.max_channel_difference,
            'read_file': renderer.read_file,
            'distinct_values': renderer.distinct_values,
            'gray_match': renderer.gray_match,
            'quarter_match': renderer.quarter_match,
            'ramp': renderer.ramp,
            'clamp_pair': renderer.clamp_pair,
            'plate_01': renderer.plate_01,
            # Chapter 2
            'circle': renderer.circle,
            'rectangle': renderer.rectangle,
            'half_plane': renderer.half_plane,
            'inside': renderer.inside,
            'magnify': renderer.magnify,
            'coverage_buffer': renderer.coverage_buffer,
            'coverage_at': renderer.coverage_at,
            'set_coverage': renderer.set_coverage,
            'ink': renderer.ink,
            'center_inside': renderer.center_inside,
            'rasterize_centers': renderer.rasterize_centers,
            'coverage': renderer.coverage,
            'rasterize': renderer.rasterize,
            'paint_through': renderer.paint_through,
            'disc_centers': renderer.disc_centers,
            'painted_twice': renderer.painted_twice,
            'disc_coverage': renderer.disc_coverage,
            'plate_02': renderer.plate_02,
            # Chapter 3
            'lit_pixels': renderer.lit_pixels,
            'line_bresenham': renderer.line_bresenham,
            'line_wu': renderer.line_wu,
            'plot': renderer.plot,
            'thick_line': renderer.thick_line,
            'total_ink': renderer.total_ink,
            'ray_ends': renderer.ray_ends,
            'fan_bresenham': renderer.fan_bresenham,
            'fan_wu': renderer.fan_wu,
            'fan_coverage': renderer.fan_coverage,
            'plate_03': renderer.plate_03,
            # Chapter 4
            'Tuple': renderer.Tuple,
            'point': renderer.point,
            'vector': renderer.vector,
            'magnitude': renderer.magnitude,
            'normalize': renderer.normalize,
            'dot': renderer.dot,
            'cross': renderer.cross,
            'Matrix3': renderer.Matrix3,
            'matrix3': renderer.matrix3,
            'identity': renderer.identity,
            'transpose': renderer.transpose,
            'determinant': renderer.determinant,
            'is_invertible': renderer.is_invertible,
            'inverse': renderer.inverse,
            'translation': renderer.translation,
            'scaling': renderer.scaling,
            'rotation': renderer.rotation,
            'shearing': renderer.shearing,
            'approx_scale': renderer.approx_scale,
            'transform_points': renderer.transform_points,
            'segment': renderer.segment,
            'union': renderer.union,
            'transformed': renderer.transformed,
            'outline': renderer.outline,
            'side_by_side': renderer.side_by_side,
            'fan_points': renderer.fan_points,
            'fan_transformed': renderer.fan_transformed,
            'fan_both_orders': renderer.fan_both_orders,
            'letter_f': renderer.letter_f,
            'f_both_orders': renderer.f_both_orders,
            'plate_04': renderer.plate_04,
            'π': math.pi,
            # Chapter 5
            'path': renderer.path,
            'move_to': renderer.move_to,
            'line_to': renderer.line_to,
            'close': renderer.close,
            'subpaths': renderer.subpaths,
            'edges': renderer.edges,
            'bounds': renderer.bounds,
            'polygon': renderer.polygon,
            'circle_path': renderer.circle_path,
            'crossings': renderer.crossings,
            'winding_at': renderer.winding_at,
            'inside_nonzero': renderer.inside_nonzero,
            'inside_evenodd': renderer.inside_evenodd,
            'filled': renderer.filled,
            'rasterize_within': renderer.rasterize_within,
            'star': renderer.star,
            'star_panel': renderer.star_panel,
            'star_centers': renderer.star_centers,
            'star_coverage': renderer.star_coverage,
            'plate_05': renderer.plate_05,
            # Chapter 6
            'edge_table': renderer.edge_table,
            'x_at': renderer.x_at,
            'crossings_on_row': renderer.crossings_on_row,
            'spans_from_crossings': renderer.spans_from_crossings,
            'spans': renderer.spans,
            'fill_span': renderer.fill_span,
            'fill_path_aliased': renderer.fill_path_aliased,
            'max_coverage_difference': renderer.max_coverage_difference,
            'transform_path': renderer.transform_path,
            'unit_star': renderer.unit_star,
            'spiral': renderer.spiral,
            'plate_06': renderer.plate_06,
            # Chapter 7
            'accumulator': renderer.accumulator,
            'area_at': renderer.area_at,
            'cover_at': renderer.cover_at,
            'add_cell': renderer.add_cell,
            'accumulate_row': renderer.accumulate_row,
            'accumulate': renderer.accumulate,
            'apply_rule': renderer.apply_rule,
            'resolve': renderer.resolve,
            'fill_path': renderer.fill_path,
            'polygon_area': renderer.polygon_area,
            'needle_path': renderer.needle_path,
            'needles': renderer.needles,
            'soft_square': renderer.soft_square,
            'star_exact': renderer.star_exact,
            'spiral_smooth': renderer.spiral_smooth,
            'rays': renderer.rays,
            'sunburst': renderer.sunburst,
            'plate_07': renderer.plate_07,
            # Chapter 8
            'quadratic': renderer.quadratic,
            'cubic': renderer.cubic,
            'point_at': renderer.point_at,
            'split_at': renderer.split_at,
            'derivative': renderer.derivative,
            'transform_curve': renderer.transform_curve,
            'curve_bounds': renderer.curve_bounds,
            'flatness': renderer.flatness,
            'flatten': renderer.flatten,
            'polyline_length': renderer.polyline_length,
            'flatten_length': renderer.flatten_length,
            'flatten_into_path': renderer.flatten_into_path,
            'arc': renderer.arc,
            'arc_point': renderer.arc_point,
            'teardrop': renderer.teardrop,
            'drops': renderer.drops,
            'petal': renderer.petal,
            'flower_at': renderer.flower_at,
            'flower': renderer.flower,
            'plate_08': renderer.plate_08,
            # Chapter 9
            'pixel': renderer.pixel,
            'from_color': renderer.from_color,
            'opaque': renderer.opaque,
            'CLEAR': renderer.CLEAR,
            'pixel_color': renderer.pixel_color,
            'pixel_alpha': renderer.pixel_alpha,
            'lerp_pixel': renderer.lerp_pixel,
            'over': renderer.over,
            'coefficients': renderer.coefficients,
            'composite': renderer.composite,
            'blend': renderer.blend,
            'blend_color': renderer.blend_color,
            'layer': renderer.layer,
            'paint_shape': renderer.paint_shape,
            'composite_layers': renderer.composite_layers,
            'flatten_layer': renderer.flatten_layer,
            'porter_duff_table': renderer.porter_duff_table,
            'plate_09': renderer.plate_09,
            'blend_strip': renderer.blend_strip,
            'seam': renderer.seam,
            # Chapter 10
            'stop': renderer.stop,
            'sample_stops': renderer.sample_stops,
            'extend': renderer.extend,
            'linear_gradient': renderer.linear_gradient,
            'linear_t': renderer.linear_t,
            'radial_gradient': renderer.radial_gradient,
            'radial_t': renderer.radial_t,
            'conic_gradient': renderer.conic_gradient,
            'conic_t': renderer.conic_t,
            'solid': renderer.solid,
            'paint_at': renderer.paint_at,
            'paint_fill': renderer.paint_fill,
            'three_gradients': renderer.three_gradients,
            'plate_10': renderer.plate_10,
            'extend_strip': renderer.extend_strip,
            'BAYER4': renderer.BAYER4,
            'dither_threshold': renderer.dither_threshold,
            'to_byte': renderer.to_byte,
            'to_byte_dithered': renderer.to_byte_dithered,
            'canvas_to_p6_dithered': renderer.canvas_to_p6_dithered,
            # Chapter 11
            'Image': renderer.Image,
            'image': renderer.image,
            'read_image': renderer.read_image,
            'image_texel': renderer.image_texel,
            'sample_nearest': renderer.sample_nearest,
            'sample_bilinear': renderer.sample_bilinear,
            'sample_bicubic': renderer.sample_bicubic,
            'catmull': renderer.catmull,
            'image_paint': renderer.image_paint,
            'downsample': renderer.downsample,
            'mip_chain': renderer.mip_chain,
            'mip_level_for': renderer.mip_level_for,
            'sprite': renderer.sprite,
            'two_filters': renderer.two_filters,
            'plate_11': renderer.plate_11,
            'three_filters': renderer.three_filters,
            # Chapter 12
            'multiply_coverage': renderer.multiply_coverage,
            'full_clip': renderer.full_clip,
            'clip_path': renderer.clip_path,
            'clip_rect': renderer.clip_rect,
            'soft_mask': renderer.soft_mask,
            'set_layer_pixel': renderer.set_layer_pixel,
            'layer_pixel': renderer.layer_pixel,
            'push_group': renderer.push_group,
            'paint_into': renderer.paint_into,
            'scale_opacity': renderer.scale_opacity,
            'pop_group_with_opacity': renderer.pop_group_with_opacity,
            'per_child': renderer.per_child,
            'group_opacity': renderer.group_opacity,
            'opacity_plate': renderer.opacity_plate,
            'plate_12': renderer.plate_12,
            'clip_demo': renderer.clip_demo,
            # Chapter 13
            'stroke_to_path': renderer.stroke_to_path,
            'miter_length': renderer.miter_length,
            'chevron': renderer.chevron,
            'joins_plate': renderer.joins_plate,
            'plate_13': renderer.plate_13,
            'caps_demo': renderer.caps_demo,
            'u_turn': renderer.u_turn,
            'sqrt': math.sqrt,
            # Chapter 14
            'tangent_at': renderer.tangent_at,
            'normal_at': renderer.normal_at,
            'offset_point': renderer.offset_point,
            'second_derivative': renderer.second_derivative,
            'curvature': renderer.curvature,
            'cusps': renderer.cusps,
            'fit_offset': renderer.fit_offset,
            'offset_error': renderer.offset_error,
            'distance_to_curve': renderer.distance_to_curve,
            'sub_curve': renderer.sub_curve,
            'offset_curve': renderer.offset_curve,
            'offset_distance_error': renderer.offset_distance_error,
            'offset_path': renderer.offset_path,
            'stroke_curve_to_path': renderer.stroke_curve_to_path,
            'flatten_then_stroke': renderer.flatten_then_stroke,
            'point_count': renderer.point_count,
            'hairpin': renderer.hairpin,
            'arch': renderer.arch,
            'two_strokes': renderer.two_strokes,
            'fold_demo': renderer.fold_demo,
            'offsets_plate': renderer.offsets_plate,
            'plate_14': renderer.plate_14,
            # Chapter 15
            'path_length': renderer.path_length,
            'arc_length_table': renderer.arc_length_table,
            'arc_length': renderer.arc_length,
            't_at_length': renderer.t_at_length,
            'point_at_length': renderer.point_at_length,
            'split_at_length': renderer.split_at_length,
            'normalize_pattern': renderer.normalize_pattern,
            'dash': renderer.dash,
            'dash_count': renderer.dash_count,
            'lopsided': renderer.lopsided,
            'even_marks': renderer.even_marks,
            'wave': renderer.wave,
            'dash_strip': renderer.dash_strip,
            'golden_spiral': renderer.golden_spiral,
            'spiral_dashes': renderer.spiral_dashes,
            'plate_15': renderer.plate_15,
            # Chapter 16
            'load_font': renderer.load_font,
            'glyph_name': renderer.glyph_name,
            'glyph_advance': renderer.glyph_advance,
            'glyph_count': renderer.glyph_count,
            'implied_points': renderer.implied_points,
            'contour_curves': renderer.contour_curves,
            'component_matrix': renderer.component_matrix,
            'glyph_outline': renderer.glyph_outline,
            'glyph_bounds': renderer.glyph_bounds,
            'text_matrix': renderer.text_matrix,
            'contour_path': renderer.contour_path,
            'glyph_path': renderer.glyph_path,
            'glyph_plate': renderer.glyph_plate,
            'plate_16': renderer.plate_16,
            'composite_demo': renderer.composite_demo,
            'sizes': renderer.sizes,
            'flip_trap': renderer.flip_trap,
            # Chapter 17
            'subpixel_of': renderer.subpixel_of,
            'Bitmap': renderer.Bitmap,
            'bitmap': renderer.bitmap,
            'glyph_bitmap': renderer.glyph_bitmap,
            'paint_bitmap': renderer.paint_bitmap,
            'glyph_cache': renderer.glyph_cache,
            'cache_size': renderer.cache_size,
            'cached_bitmap': renderer.cached_bitmap,
            'atlas': renderer.atlas,
            'atlas_add': renderer.atlas_add,
            'embolden': renderer.embolden,
            'LCD_TAPS': renderer.LCD_TAPS,
            'lcd_filter': renderer.lcd_filter,
            'lcd_coverage': renderer.lcd_coverage,
            'paint_lcd': renderer.paint_lcd,
            'pen_advance': renderer.pen_advance,
            'draw_text': renderer.draw_text,
            'subpixel_strip': renderer.subpixel_strip,
            'smoothing_demo': renderer.smoothing_demo,
            'lcd_plate': renderer.lcd_plate,
            'plate_17': renderer.plate_17,
            # Chapter 18
            'Placement': renderer.Placement,
            'ascent': renderer.ascent,
            'descent': renderer.descent,
            'line_height': renderer.line_height,
            'kern': renderer.kern,
            'layout_run': renderer.layout_run,
            'run_advance': renderer.run_advance,
            'break_lines': renderer.break_lines,
            'layout_line': renderer.layout_line,
            'layout_paragraph': renderer.layout_paragraph,
            'draw_run': renderer.draw_run,
            'THROUGH_LINE': renderer.THROUGH_LINE,
            'kern_demo': renderer.kern_demo,
            'break_demo': renderer.break_demo,
            'drift_demo': renderer.drift_demo,
            'alignment_plate': renderer.alignment_plate,
            'plate_18': renderer.plate_18,
            # Chapter 19
            'Item': renderer.Item,
            'script_of': renderer.script_of,
            'itemize': renderer.itemize,
            'GlyphEntry': renderer.GlyphEntry,
            'glyph_buffer': renderer.glyph_buffer,
            'clusters': renderer.clusters,
            'apply_ligatures': renderer.apply_ligatures,
            'joining_type': renderer.joining_type,
            'arabic_forms': renderer.arabic_forms,
            'apply_forms': renderer.apply_forms,
            'is_mark': renderer.is_mark,
            'attach_marks': renderer.attach_marks,
            'shape': renderer.shape,
            'buffer_advance': renderer.buffer_advance,
            'position': renderer.position,
            'caret_offsets': renderer.caret_offsets,
            'caret_positions': renderer.caret_positions,
            'ligature_demo': renderer.ligature_demo,
            'forms_demo': renderer.forms_demo,
            'word_demo': renderer.word_demo,
            'mixed_demo': renderer.mixed_demo,
            'cluster_plate': renderer.cluster_plate,
            'plate_19': renderer.plate_19,
            # Chapter 20
            'parse_xml': renderer.parse_xml,
            'attribute': renderer.attribute,
            'children': renderer.children,
            'find_by_id': renderer.find_by_id,
            'read_number': renderer.read_number,
            'number_list': renderer.number_list,
            'read_flag': renderer.read_flag,
            'path_commands': renderer.path_commands,
            'arc_cubics': renderer.arc_cubics,
            'build_path': renderer.build_path,
            'commands_bounds': renderer.commands_bounds,
            'parse_transform': renderer.parse_transform,
            'parse_color': renderer.parse_color,
            'computed_style': renderer.computed_style,
            'initial_style': renderer.initial_style,
            'shape_commands': renderer.shape_commands,
            'view_box_matrix': renderer.view_box_matrix,
            'transformed_paint': renderer.transformed_paint,
            'gradient_stops': renderer.gradient_stops,
            'paint_server': renderer.paint_server,
            'draw_coverage': renderer.draw_coverage,
            'union_coverage': renderer.union_coverage,
            'clip_coverage': renderer.clip_coverage,
            'mask_layer': renderer.mask_layer,
            'render_svg': renderer.render_svg,
            'aspect_demo': renderer.aspect_demo,
            'harbor': renderer.harbor,
            'rose': renderer.rose,
            'tiger': renderer.tiger,
            'plate_20': renderer.plate_20,
            # Chapter 21
            'stats': renderer.stats,
            'fill_path_counted': renderer.fill_path_counted,
            'draw_coverage_counted': renderer.draw_coverage_counted,
            'render_svg_with': renderer.render_svg_with,
            'fill_bounds': renderer.fill_bounds,
            'fill_path_bounded': renderer.fill_path_bounded,
            'coverage_in': renderer.coverage_in,
            'full_coverage': renderer.full_coverage,
            'draw_window': renderer.draw_window,
            'classify_tiles': renderer.classify_tiles,
            'fill_path_tiled': renderer.fill_path_tiled,
            'tile_count': renderer.tile_count,
            'draw_tiled': renderer.draw_tiled,
            'composite_span': renderer.composite_span,
            'composite_span4': renderer.composite_span4,
            'layers_equal': renderer.layers_equal,
            'tile_work': renderer.tile_work,
            'work_map': renderer.work_map,
            'plate_21': renderer.plate_21,
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
        elif isinstance(left_val, renderer.Tuple) and isinstance(right_val, renderer.Tuple):
            return (abs(left_val.x - right_val.x) <= tolerance and
                    abs(left_val.y - right_val.y) <= tolerance and
                    abs(left_val.w - right_val.w) <= tolerance)
        elif isinstance(left_val, renderer.Matrix3) and isinstance(right_val, renderer.Matrix3):
            return all(abs(a - b) <= tolerance for a, b in zip(left_val.values, right_val.values))
        elif isinstance(left_val, (int, float)) and isinstance(right_val, (int, float)):
            return abs(left_val - right_val) <= tolerance
        elif isinstance(left_val, (tuple, list)) and isinstance(right_val, (tuple, list)):
            # Compare tuples/lists element-wise, recursively (so a list of
            # (x, direction) crossings or spans compares each float with
            # the usual tolerance instead of falling back to exact ==).
            if len(left_val) != len(right_val):
                return False
            return all(compare_values(a, b, '=', tolerance) for a, b in zip(left_val, right_val))
        else:
            return left_val == right_val
    elif op in ['≠', '!=']:
        return not compare_values(left_val, right_val, '=', tolerance)
    elif op == '<':
        return left_val < right_val
    elif op in ('<=', '≤'):
        return left_val <= right_val
    elif op == '>':
        return left_val > right_val
    elif op in ('>=', '≥'):
        return left_val >= right_val
    return False


def execute_step(step_keyword, step_text, ctx, docstring=None):
    """Execute a single step and update context."""
    # Handle "Given the following matrix M:" with docstring table
    match = re.match(r'the following matrix (\w+):', step_text)
    if match and docstring:
        matrix_name = match.group(1)
        # Parse the table from docstring
        lines = docstring.strip().split('\n')
        values = []
        for line in lines:
            # Each line should be like "| 1 | 2 | 3 |"
            cells = [c.strip() for c in line.split('|')]
            cells = [c for c in cells if c]  # Remove empty strings
            try:
                values.extend([float(c) for c in cells])
            except ValueError:
                return False, f"Could not parse matrix values in line: {line}"

        if len(values) != 9:
            return False, f"Matrix must have 9 values, got {len(values)}"

        matrix = renderer.matrix3(*values)
        ctx.set(matrix_name, matrix)
        return True, None

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

    # Handle "X is the following matrix:" with docstring table
    match = re.match(r'(\w+)\s+is the following matrix:', step_text)
    if match and docstring:
        matrix_var = match.group(1)
        # Parse the table from docstring
        lines = docstring.strip().split('\n')
        values = []
        for line in lines:
            # Each line should be like "| 1 | 2 | 3 |"
            cells = [c.strip() for c in line.split('|')]
            cells = [c for c in cells if c]  # Remove empty strings
            try:
                values.extend([float(c) for c in cells])
            except ValueError:
                return False, f"Could not parse matrix values in line: {line}"

        if len(values) != 9:
            return False, f"Matrix must have 9 values, got {len(values)}"

        expected_matrix = renderer.matrix3(*values)
        actual_matrix = ctx.get(matrix_var)

        if not compare_values(actual_matrix, expected_matrix, '=', 0.0001):
            return False, f"Matrix {matrix_var} does not match expected values"
        return True, None

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

    # Handle "byte N of var = M" (before generic comparison)
    # Note: byte numbering in tests is 1-indexed
    match = re.match(r'byte\s+(\d+)\s+of\s+(\w+)\s*=\s*(\d+)', step_text)
    if match:
        byte_idx = int(match.group(1)) - 1  # Convert from 1-indexed to 0-indexed
        var_name = match.group(2)
        expected_val = int(match.group(3))
        value = ctx.get(var_name)
        if isinstance(value, bytes):
            actual_val = value[byte_idx]
        else:
            # Convert string to bytes
            value_bytes = value.encode('latin-1')
            actual_val = value_bytes[byte_idx]
        if actual_val != expected_val:
            return False, f"byte {byte_idx + 1} of {var_name} = {actual_val}, expected {expected_val}"
        return True, None

    # Handle comparisons
    if any(op in step_text for op in ['=', '≠', '!=', '<', '<=', '>', '>=', '≤', '≥']):
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

    # Handle "[exactly] N pixels of c are color(...)"
    match = re.match(r'(?:exactly\s+)?(\d+) pixels of (\w+) are color\((.*?)\)', step_text)
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
    match = re.match(r'max_channel_difference\((\w+),\s*(\w+)\)\s*([<>=≠!≤≥]+)\s*(\d+)', step_text)
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
        elif op in ('<=', '≤') and actual > expected:
            return False, f"max_channel_difference = {actual}, expected <= {expected}"
        elif op in ('>=', '≥') and actual < expected:
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

    # Handle "p6 begins with ..."
    match = re.match(r'(\w+)\s+begins with\s+"(.*?)"', step_text)
    if match:
        var_name = match.group(1)
        expected_start = match.group(2)
        # Unescape the expected string
        expected_start = expected_start.replace('\\n', '\n')
        value = ctx.get(var_name)
        if isinstance(value, bytes):
            value_str = value.decode('latin-1')
        else:
            value_str = value
        if not value_str.startswith(expected_start):
            return False, f"'{var_name}' does not begin with '{expected_start}', got '{value_str[:len(expected_start)]}...'"
        return True, None

    # Handle "length(var) = N"
    match = re.match(r'length\((\w+)\)\s*=\s*(\d+)', step_text)
    if match:
        var_name = match.group(1)
        expected_len = int(match.group(2))
        value = ctx.get(var_name)
        if isinstance(value, bytes):
            actual_len = len(value)
        else:
            actual_len = len(value)
        if actual_len != expected_len:
            return False, f"length({var_name}) = {actual_len}, expected {expected_len}"
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
