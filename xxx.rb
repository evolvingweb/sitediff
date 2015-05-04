class Munger
  Part = Struct.new(:type, :name)

  def initialize
    @munged = {}
    @parts = {}
  end

  def add(path)
    if m = @munged[path]
      return m
    end

    esc = path.gsub(/,/, ',,') # Escape commas
    segments = esc.split(File::SEPARATOR)
    @munged[path] = _add('', segments)
  end

  def _add(pref, segments)
    return pref if segments.empty?

    seg = segments.shift
    seg += "/#{segments.shift}" while %r{^/*$}.match(seg) && !segments.empty?
    type = segments.empty? ? :file : :dir

    suf = 0
    loop do
      name = seg.gsub(%r{^/*}, '')
      name += ",#{suf}" if !suf.zero? || seg.empty?
      part = Part.new(type, seg)
      path = pref.empty? ? name : File.join(pref, name)
      canon = path.downcase

      @parts[canon] ||= part
      return _add(path, segments) if @parts[canon] == part

      suf += 1
    end
  end
end

files = <<EOF.split("\n")
foo
/foo
/bar
/bar/blah
/Bar
/bar/iggy
/foo,
EOF

munger = Munger.new
files.each do |file|
  munged = munger.add(file)
  puts "%-40s -> %s" % [file, munged]
end
