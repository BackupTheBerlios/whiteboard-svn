whiteboard:
	ruby main.rb |grep -v '(eval)\|/usr/local/lib/ruby/1\.8/yaml'

install: mainwindow.ui
	rbuic mainwindow.ui > mainwindow.rb
	rbuic object_properties.ui > object_properties.rb
	ruby fix_ui_types.rb > object_properties2.rb
	rm object_properties.rb
	mv object_properties2.rb object_properties.rb
