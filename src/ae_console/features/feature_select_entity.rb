module AE

  module ConsolePlugin

    class FeatureSelectEntity

      require(File.join(PATH, 'features', 'entity_highlight_tool.rb'))

      def initialize(app)
        app.plugin.on(:console_added){ |console|
          dialog = console.dialog

          dialog.on('modifier_keys') { |action_context, hash|
            SelectEntityTool.mode_pick_entity_instead_of_point = (not hash['ctrl'])
            SelectEntityTool.mode_use_inferencing = hash['shift']
          }

          dialog.on('select_entity') { |action_context, desired_name|
            # This triggers the built-in select tool and once an entity is selected,
            # a local variable is created in binding and its name is returned.
            SelectEntityTool.select_tool.then(proc{ |selected|
              #  Entity was selected and referenced by a variable with this name.
              binding = console.instance_variable_get(:@binding)
              name = create_reference_name(selected, binding, desired_name)
              create_reference(name, selected, binding)
              # Resolve the promise
              action_context.resolve(name)
            }, proc{ |error|
              # Tool was cancelled.
              action_context.reject(error)
            })
          }

          console.on(:closed) {
            SelectEntityTool.deselect_tool # TODO: only if SelectEntityTool was active tool
          }

        }
      end

      def create_reference_name(object, binding, desired_name=nil)
        if desired_name.is_a?(String) && desired_name[/^[^\!\"\'\`\@\$\%\|\&\/\(\)\[\]\{\}\,\;\?\<\>\=\+\-\*\/\#\~\\]+$/] #"
          return desired_name
        else
          name = main_name = create_entity_name(object)
          # If a reference with same name exists already, increment it.
          i = 0
          while binding.eval("defined?(#{name})") && object != binding.eval("#{name}")
            i += 1
            name = "#{main_name}#{i}" 
          end
          return name
        end
      end

      def create_entity_name(entity)
        case entity
          # Short names: (You can add more)
        when Sketchup::ComponentInstance
          return 'component'
        when Geom::Point3d
          return 'p'
          # Or generic name:
        else
          if entity.respond_to?(:typename)
            return entity.typename.downcase
          else
            return entity.class.name.to_s[/[^\:]+$/].downcase
          end
        end
      end

      def create_reference(name, object, binding)
        id = object.object_id
        binding.eval("#{name} = ObjectSpace._id2ref(#{id})")
        nil
      end

      def get_javascript_path
        return 'feature_select_entity.js'
      end

      class SelectEntityTool

        if Sketchup.version.to_i >= 16
          if RUBY_PLATFORM =~ /darwin/
            IMG_CURSOR_SELECT_ENTITY = File.join(PATH, 'images', 'cursor_select_entity.pdf')
          else
            IMG_CURSOR_SELECT_ENTITY = File.join(PATH, 'images', 'cursor_select_entity.svg')
          end
        else
          IMG_CURSOR_SELECT_ENTITY = File.join(PATH, 'images', 'cursor_select_entity.png')
        end

        def self.select_tool()
          promise = AE::ConsolePlugin::Bridge::Promise.new{ |resolver, rejector|
            instance = self.new(resolver, rejector)
            Sketchup.active_model.tools.push_tool(instance)
          }
          return promise
        end

        def self.deselect_tool
          Sketchup.active_model.tools.pop_tool # assuming active model is not changed
        end

        @mode_use_inferencing = false
        @mode_pick_entity_instead_of_point = true
        class << self
          attr_accessor :mode_use_inferencing, :mode_pick_entity_instead_of_point
        end

        def initialize(resolver=nil, rejector=nil)
          @resolver = resolver
          @rejector = rejector
          @highlighter = EntityHighlightTool.new
          @model = Sketchup.active_model
          @cursor = UI::create_cursor(IMG_CURSOR_SELECT_ENTITY, 10, 10)
          @ip = Sketchup::InputPoint.new
        end

        def activate
          Sketchup.status_text = TRANSLATE["Click to select an entity. Right-click to abort. Press the ctrl key to select points. Press the shift key to use inferencing."]
        end


        def deactivate(view)
          view.invalidate
          # Reject promise if not yet resolved
          begin
            @rejector.call('Tool deactivated') if @rejector
          rescue Exception => e # It may have been already resolved.
          end
        end

        def onSetCursor
          UI.set_cursor(@cursor)
        end

        def onMouseMove(flags, x, y, view)
          if self.class.mode_pick_entity_instead_of_point
            @highlighter.highlight(pick_entity(view, x, y))
          else
            @highlighter.highlight(pick_point(view, x, y))
          end
        end

        def onLButtonDown(flags, x, y, view)
          if self.class.mode_pick_entity_instead_of_point
            @highlighter.highlight(pick_entity(view, x, y))
          else
            @highlighter.highlight(pick_point(view, x, y))
          end
        end

        def onLButtonUp(flags, x, y, view)
          if self.class.mode_pick_entity_instead_of_point
            selected = pick_entity(view, x, y)
          else
            selected = pick_point(view, x, y)
          end
          if !selected.nil?
            @resolver.call(selected) if @resolver
            # Deselect this tool.
            deselect_tool
          end
        end

        def getMenu(menu)
          deselect_tool
        end

        def onRButtonDown(flags, x, y, view)
          deselect_tool
        end

        def onKeyDown(key, repeat, flags, view)
          self.class.mode_pick_entity_instead_of_point = false if key == COPY_MODIFIER_KEY      # VK_CONTROL
          self.class.mode_use_inferencing              = true  if key == CONSTRAIN_MODIFIER_KEY # VK_SHIFT
        end

        def onKeyUp(key, repeat, flags, view)
          self.class.mode_pick_entity_instead_of_point = true  if key == COPY_MODIFIER_KEY      # VK_CONTROL
          self.class.mode_use_inferencing              = false if key == CONSTRAIN_MODIFIER_KEY # VK_SHIFT
        end

        def draw(view)
          @highlighter.draw(view)
        end

        private

        def deselect_tool
          Sketchup.active_model.tools.pop_tool # assuming active model is not changed # TODO
        end

        # Get an entity is under the cursor.
        def pick_entity(view, x, y)
          if self.class.mode_use_inferencing
            return pick_entity_inferenced(view, x, y)
          else
            return pick_entity_exact(view, x, y)
          end
        end

        # Without inferencing: use PickHelper
        def pick_entity_exact(view, x, y)
          pick_helper = view.pick_helper
          pick_helper.do_pick(x, y)
          result = pick_helper.best_picked
          return nil unless result
          result = result.curve if result.is_a?(Sketchup::Edge) && result.curve
          return result
        end

        # With inferencing: use InputPoint
        def pick_entity_inferenced(view, x, y)
          @ip.pick(view, x, y)
          return nil unless @ip.valid?
          return @ip.edge || @ip.face
        end

        # Get point/inference under cursor.
        def pick_point(view, x, y)
          if self.class.mode_use_inferencing
            return pick_point_inferenced(view, x, y)
          else
            return pick_point_exact(view, x, y)
          end
        end

        # Without inferencing: use a raytest
        def pick_point_exact(view, x, y)
          ray    = view.pickray(x, y)
          result = @model.raytest(ray)
          return nil unless result
          return result.first.transform(@model.edit_transform.inverse)
        end

        # With inferencing: use InputPoint
        def pick_point_inferenced(view, x, y)
          @ip.pick(view, x, y)
          return unless @ip.valid?
          return @ip.position.transform(@model.edit_transform.inverse)
        end

      end # class SelectEntityTool

    end # class FeatureSelectEntity

  end # module ConsolePlugin

end # module AE