#!/usr/bin/env ruby

require 'gtk2'
require 'poppler'

class PDFDocument
  def initialize(pdf_filename, blank_page_filename=nil)
    if blank_page_filename
    end
    @document = Poppler::Document.new(pdf_filename)
    total_page = @document.size
    @page = -1
    @page_map = []
    (0..total_page).each { |i|
      @page_map[i] = i
    }

  end

  def page_size(page=0)
    @document[page].size
  end

  def render_page(context, page)
    if page > -1 && page < @page_map.size && @page_map[page]
      context.render_poppler_page(@document[@page_map[page]])
    end
  end

  def draw(context, context_width, context_height)
    context.save do
      page_width, page_height = self.page_size(@page + 1).map { |e| e.to_f}

      context_width = context_width.to_f
      context_height = context_height.to_f

      if (context_width / context_height) >= (page_width * 2 / page_height)
        scale_rate = context_height / page_height
        context.scale(scale_rate, scale_rate)
        context.translate((context_width - scale_rate* 2 * page_width) / scale_rate / 2, 0)
      else
        scale_rate = context_width / page_width / 2
        context.scale(scale_rate, scale_rate)
        context.translate(0, (context_height- scale_rate* page_height) / scale_rate / 2)
      end

      render_page(context, @page + 1)
      context.translate(page_width, 0)
      render_page(context, @page)
    end
  end

  def forward_pages
    @page += 2
  end

  def back_pages
    @page -= 2
  end

  def insert_blank_page_to_left
    @page_map.insert(@page + 1 , nil)
  end

  def insert_blank_page_to_right
    @page_map.insert(@page , nil)
  end
end

if ARGV.size < 1
  puts "Usage: #{$0} file"
  exit 1
end

document = PDFDocument.new(ARGV[0])

window = Gtk::Window.new

drawing_area = Gtk::DrawingArea.new
drawing_area.signal_connect('expose-event') do |widget, event|
  context = widget.window.create_cairo_context
  x, y, w, h = widget.allocation.to_a

  #背景の塗り潰し
  context.set_source_rgb(1, 1, 1)
  context.rectangle(0, 0, w, h)
  context.fill

  document.draw(context, w, h)
  true
end

window.signal_connect('key-press-event') do |widget, event|
  case(event.keyval)
    when 32 #space
      document.forward_pages
    when 65288,98 # backspace, b
      document.back_pages
    when 108 # l
      document.insert_blank_page_to_left
    when 114 # r
      document.insert_blank_page_to_right
  end
  drawing_area.signal_emit('expose-event', event)
  true
end

window.add(drawing_area)

page_width, page_height = document.page_size
window.set_default_size(page_width*2, page_height)
window.signal_connect("destroy") do
  Gtk.main_quit
  false
end

window.show_all
Gtk.main
