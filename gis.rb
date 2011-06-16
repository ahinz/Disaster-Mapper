def contains_point?(x,y,polygon)
  contains_point = false
  i = -1
  j = polygon.size - 1
  while (i += 1) < polygon.size
    a_point_on_polygon = polygon[i]
    trailing_point_on_polygon = polygon[j]
    if point_is_between_the_ys_of_the_line_segment?(y, a_point_on_polygon[1], trailing_point_on_polygon[1])
      if ray_crosses_through_line_segment?(x, y, a_point_on_polygon[0], a_point_on_polygon[1], trailing_point_on_polygon[0], trailing_point_on_polygon[1])
        contains_point = !contains_point
      end
    end
    j = i
  end
  return contains_point
end

private

def point_is_between_the_ys_of_the_line_segment?(point_y, a_point_on_polygon_y, trailing_point_on_polygon_y)
  (a_point_on_polygon_y <= point_y && point_y < trailing_point_on_polygon_y) || 
  (trailing_point_on_polygon_y <= point_y && point_y < a_point_on_polygon_y)
end

def ray_crosses_through_line_segment?(x, y, a_point_on_polygon_x, a_point_on_polygon_y, trailing_point_on_polygon_x, trailing_point_on_polygon_y)
  (x < (trailing_point_on_polygon_x - a_point_on_polygon_x) * (y - a_point_on_polygon_y) / 
             (trailing_point_on_polygon_y - a_point_on_polygon_y) + a_point_on_polygon_x)
end
