class WhiteboardObjectController
  signals 'itemCreated(WhiteboardObject)', 'itemModified(WhiteboardObject)'

  def initialize(mainWidget)
    $log.info caller.join("\n")
    @canvas = mainWidget.canvas
    @mainWidget = mainWidget
  end

  def mousePress(e) end
  def mouseMove(e) end
  def mouseRelease(e) end
  def create(p) end
  def object_selected(o) end
end

class WhiteboardObject
  attr_reader :canvas_items, :controller
end
