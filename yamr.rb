#!/usr/bin/env ruby

require 'gtk2'
require 'poppler'

class PDFDocument
  def initialize(pdf_filename, blank_page_filename=nil)
    if blank_page_filename
    end
    @document = Poppler::Document.new(pdf_filename)
    @page = -1
  end

  def size
    #@document[@page].size
    @document[0].size
  end

  def draw(context, w, h)
    context.save do
      image_width, image_height = self.size
      context.scale(w / 2 / image_width.to_f, h / image_height.to_f)
      if @page > -2
        context.render_poppler_page(@document[@page+1])
      end
      context.translate(image_width, 0)
      if @page > -1
        context.render_poppler_page(@document[@page])
      end
    end
  end

  def turn_pages
    @page += 2
  end

end


if ARGV.size < 1
  puts "Usage: #{$0} file"
  exit 1
end

document = PDFDocument.new(ARGV[0])

window = Gtk::Window.new

image_width, image_height = document.size
window.set_default_size(image_width*2, image_height)
window.signal_connect("destroy") do
  Gtk.main_quit
  false
end

drawing_area = Gtk::DrawingArea.new
drawing_area.signal_connect('expose-event') do |widget, event|
  context = widget.window.create_cairo_context
  context.fill
  x, y, w, h = widget.allocation.to_a
  context.set_source_rgb(1, 1, 1) # white
  context.rectangle(0, 0, w, h)
  context.fill
  document.draw(context, w, h)
  true
end

window.signal_connect('key-press-event') do |widget, event|
  document.turn_pages
  drawing_area.signal_emit('expose-event', event)
  true
end

window.add(drawing_area)
window.show_all

Gtk.main
