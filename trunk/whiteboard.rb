#!/usr/bin/env ruby
$VERBOSE = true; $:.unshift File.dirname($0)

require 'Qt'
class WhiteboardMainWindow < Qt::MainWindow
	def initialize()
		super
		@toolbar = Qt::ToolBar.new("hello", self)
		@toolbar.label = "hello"
		@toolbar.addSeparator()
		@toolbar.show()

		menuBar().insertItem("&File", Qt::PopupMenu.new(self))

		statusBar().message("Welcome to whiteboard!", 2000)

		@widget = WhiteboardMainWidget.new(self)
		@widget.show()
		setCentralWidget(@widget)
	end
end

class WhiteboardMainWidget < Qt::Widget
	slots 'addEquation()' 

	$controlPointSize = 10
	$objectMinimumSize = 10
	$numRectangleControlPoints = 8

	def initialize(parent)
		super(parent)
				
		layout = Qt::GridLayout.new(self, 2, 2)

		@canvas = Qt::Canvas.new(2000, 2000)
		@canvas.resize( 300, 300 )
		@canvasView = Qt::CanvasView.new( @canvas, self )
		@canvasView.show()

		@textBox = Qt::TextEdit.new(self)
		@textBox.show()

		addButton = Qt::PushButton.new('&Add', self)
		addButton.show()

		connect( addButton, SIGNAL('clicked()'), SLOT('addEquation()') )

		layout.addMultiCellWidget(@canvasView, 0, 0, 0, 0)
		layout.addWidget(@textBox, 1, 0)
		layout.addWidget(addButton, 1, 1)

		@rects = []
	end

	def addEquation()
		@currentObject = WhiteboardMathObject.new(@textBox.text, @canvas)
		@currentObject.show()
		@canvas.update()
	end

	def updateRects(br)
		@rectHash = {}
		i = 1
		for x in [[-1, br.left], [0, (br.right+br.left)/2], [1, br.right]]
			for y in [[-1, br.top], [0, (br.top+br.bottom)/2], [1, br.bottom]]
				if x[1] != (br.right+br.left)/2 or y[1] != (br.top+br.bottom)/2
					@rects[i].move(x[1] - $controlPointSize/2, y[1] - $controlPointSize/2)
					@rectHash[@rects[i]] = [x[0], y[0]]
					i += 1
				end
			end
		end
	end

	def mousePressEvent(e)
		cols = @canvas.collisions(e.pos)
		clickedRect = @rects.find { |rect| rect == cols[0] } 
		if cols.length >= 1 and clickedRect == nil
			if !defined? @selectedObject or @selectedObject != @currentObject
				@selectedObject = cols[0]
				@draggedObject = cols[0]
				for rect in @rects
					rect.hide()
					rect = nil
				end	
				@rects = []
				@rects += [Qt::CanvasRectangle.new(@currentObject.boundingRect, @canvas)]
				for i in 1..$numRectangleControlPoints
					rect = Qt::CanvasRectangle.new(0, 0, $controlPointSize, $controlPointSize, @canvas)
					rect.z = 1 #control points go on top of object
					rect.show()
					@rects += [rect]
				end
				updateRects(cols[0].boundingRect)
			end
		elsif cols.length >= 1 
			@draggedObject = clickedRect
		else
			@draggedObject = nil
		end
		
		@mousePos = Qt::Point.new(e.pos.x, e.pos.y)
	end

	def mouseDoubleClickEvent(e)
		cols = @canvas.collisions(e.pos)
		if cols.length >= 1 and cols[0] == @currentObject
			@textEdit = Qt::MultiLineEdit.new(self)
			@textEdit.move(e.pos)
			@textEdit.resize(100, 50)
			@textEdit.show()
		end
	end

	def mouseReleaseEvent(e)
		@draggedObject = nil
		@canvas.update()
	end

	def mouseMoveEvent(e)
		dx = e.pos.x - @mousePos.x
		dy = e.pos.y - @mousePos.y
	
		if defined? @draggedObject and @draggedObject != nil
			if @draggedObject == @currentObject || @draggedObject == @rects[0]
				@draggedObject.moveBy(dx, dy)
				if @draggedObject == @currentObject
					for rect in @rects
						rect.moveBy(e.pos.x - @mousePos.x, e.pos.y - @mousePos.y)
					end
				end
			else
				cp = @rectHash[@draggedObject]
				newWidth = @currentObject.width + cp[0]*dx
				newHeight = @currentObject.height + cp[1]*dy
				if newWidth < $objectMinimumSize or newHeight < $objectMinimumSize
					#this is probably not as nice as it could be
					Qt::Cursor.setPos(mapToGlobal(@mousePos))
					return
				end
				@currentObject.resize(newWidth, newHeight)
				@currentObject.moveBy(dx, 0) if cp[0] == -1
				@currentObject.moveBy(0, dy) if cp[1] == -1
				updateRects(@currentObject.boundingRect)
			end
			@canvas.update()
		end
		@mousePos = Qt::Point.new(e.pos.x, e.pos.y)
	end

	def contextMenuEvent(e)
		menu = Qt::PopupMenu.new(self)
		caption = Qt::Label.new("<font color=darkblue><u><b>Context Menu</b></u></font>", self)
    caption.setAlignment( Qt::AlignCenter );
		menu.insertItem(caption)
		menu.insertItem( "&Rectangle", 1, 1 )
    menu.exec( Qt::Cursor.pos() );
	end
end

class WhiteboardMathObject < Qt::CanvasSprite
	def initialize(text, canvas)
		super(nil, canvas)
		@text = text
		@canvas = canvas
		system("kopete_latexconvert.sh '" + @text + "'")
		#this temporary (@image) is necessary coz of strange garbage collection issues	
		@image = Qt::Image.new("out.png")
		@originalImage = @image.copy()
		pixM = Qt::Pixmap.new(@image)
		@pix = Qt::CanvasPixmapArray.new([pixM])
		setSequence(@pix)
	end

	def resize(x, y)
		@image = @originalImage.scale(x, y)
		pixM = Qt::Pixmap.new(@image)
		@pix = Qt::CanvasPixmapArray.new([pixM])
		self.sequence = @pix
	end
end

a = Qt::Application.new(ARGV)
w = WhiteboardMainWindow.new()
w.resize(300, 300)
w.show()
a.setMainWidget(w)
a.exec
