#!/usr/bin/env ruby

require 'English'
require 'gtk2'
require 'poppler'

class PDFDocument
  def initialize(pdf_filename)
    @document = Poppler::Document.new(pdf_filename)
    total_page = @document.size
    @virtual_page = -1
    @page_map = []
    (0..total_page - 1).each { |i|
      @page_map[i] = i
    }

  end

  def actual_page(virtual_page)
      if virtual_page > -1 && virtual_page < @page_map.size && @page_map[virtual_page]
        return @page_map[virtual_page]
      end
      return nil
  end

  def page_size(virtual_page = 0)
    actual_page = actual_page(virtual_page)
    return @document[actual_page].size if actual_page
    return nil
  end

  def render_page(context, virtual_page)
    begin
      actual_page = actual_page(virtual_page)
      context.render_poppler_page(@document[actual_page]) if actual_page
    rescue => e
      STDERR.puts e.backtrace.join(', ')
    end
  end

  def draw(context, context_width, context_height)

    page_size = self.page_size(@virtual_page + 1)
    page_size = self.page_size(@virtual_page) unless page_size
    return unless page_size
    page_width, page_height = page_size.map { |e| e.to_f }

    context_width = context_width.to_f
    context_height = context_height.to_f

    context.save do

      if (context_width / context_height) >= (page_width * 2 / page_height)
        scale_rate = context_height / page_height
        context.scale(scale_rate, scale_rate)
        context.translate((context_width - scale_rate * 2 * page_width) / scale_rate / 2, 0)
      else
        scale_rate = context_width / page_width / 2
        context.scale(scale_rate, scale_rate)
        context.translate(0, (context_height - scale_rate * page_height) / scale_rate / 2)
      end

      render_page(context, @virtual_page + 1)
      context.translate(page_width, 0)
      render_page(context, @virtual_page)
    end
  end

  def forward_pages
    @virtual_page += 2 if @virtual_page < (@page_map.size - 2)
  end

  def back_pages
    @virtual_page -= 2 if @virtual_page > 0
  end

  def insert_blank_page_to_left
    @page_map.insert(@virtual_page + 1 , nil)
  end

  def insert_blank_page_to_right
    @page_map.insert(@virtual_page, nil)
  end
end

if ARGV.size < 1
  puts "Usage: #{$PROGRAM_NAME} file"
  exit 1
end

document = PDFDocument.new(ARGV[0])

window = Gtk::Window.new

drawing_area = Gtk::DrawingArea.new
drawing_area.signal_connect('expose-event') do |widget, event|
  context = widget.window.create_cairo_context
  _, _, w, h = widget.allocation.to_a

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
  when 65288, 98 # backspace, b
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
window.set_default_size(page_width * 2, page_height)
window.signal_connect("destroy") do
  Gtk.main_quit
  false
end

window.show_all
Gtk.main
