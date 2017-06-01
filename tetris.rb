%w{rubygems gosu}.each { |x| require x }

class Gosu::Window
	Width = 1000
	Height = 1200
end

class GameObject
	attr_accessor	:x, :y
	@@cells = []		
	@@colors =[0xFF0000FF, 0xFFFF0000, 0xFFFFFF00, 0xFF00FF00, 0xFFCC0099]	
	@@shapes=[
		[[0,0], [1,0], [0,1], [-1,1]], 
		[[-1, 0], [0,0], [1,0], [0,1]], 
		[[-1,0], [0,0], [1,0], [2,0]], 
		[[0, -1], [0,0], [0,1], [-1,1]], 
		[[0, -1], [0,0], [0,1], [1,1]], 
		[[-1,0], [0,0], [0,1], [1,1]],
		[[-1, 0], [0,0], [-1, 1], [0,1]]
		]		
	@@deletion_noise = Gosu::Sample.new("line.wav")

	def initialize (x, y, color)
		@x, @y, @color = x, y, color
		@image = Gosu::Image.new($window, "block.png", 1)
	end
		
	def cell(x, y)
		begin
			@@cells[x][y]
		
		rescue NoMethodError
			return GridCell.new(x, y, true)
		end
	end
	
	def cell_row(y)
		row = []
		(0...Grid::Width).each do |x|		
			row << @@cells[x][y]
		end
		row
	end
	
	def check_for_deletion(row = @y)
		if cell_row(row).all? {|cell| cell.filled?}
			cell_row(row).each {|cell| cell.empty}
			@@deletion_noise.play
		end		
	end
	
	def game_over?
		cell_row(0).any? {|cell| cell.filled?}
	end
	
	def draw
		@image.draw(@x*Grid::Block_Size + Grid::Left_Edge, @y*Grid::Block_Size+Grid::Top_Edge, 2, 1, 1, @color)
	end
end

class Grid < GameObject
	Block_Size = 36
	Width = 15 #in blocks
	Height = 25 #in blocks
	Left_Edge = (Gosu::Window::Width - Width*Block_Size)/2
	Top_Edge = 50
	
	def initialize
		@image = Gosu::Image.new($window, "border.png", 1)
		@x, @y = Left_Edge, Top_Edge
		create_empty_cells
	end

	def create_empty_cells
		(Width).times { @@cells << Array.new }
		@@cells.each_index { |x| (0...Height).each { |y| @@cells[x][y] = GridCell.new(x, y) } }
	end
	
	def draw
		@image.draw(@x, @y, 1, Width, Height, 0xFF555555)
	end
end

class GridCell < GameObject

	def initialize (x, y, filled = false)
		super(x, y, 0x00000000)
		@filled = filled
	end
	
	def filled?
		@filled
	end
	
	def fill(color = 0xFFFFFFFF)
		@filled, @color = true, color
	end
	
	def empty
		@filled, @color = false, 0x00000000
		$window.score += 10
		cell(@x, @y-1).fall if cell(@x, @y-1).filled?
	end
	
	def fall
		cell(@x, @y+1).fill(@color)
		empty
	end
end

class FallingBlock < GameObject

	attr_accessor	:segments
	MOVE_SPEED = 1	
	@@fall_counter = 0	
	
	def initialize(shape = @@shapes.shuffle.first, color = @@colors[rand(0..4)])
		@x = Grid::Width / 2
		@y = 0
		@color = color
		@matrix = shape
		@segments = []
		
		create_segments		
	end
	
	def transform_matrix		
		@matrix.map { |x, y| x = y *- 1, y = x }
	end
	
	def transform_matrix!
		@matrix.map! { |x, y| x = y *- 1, y = x }
	end
	
	def create_segments
		@matrix.each_with_index { |xy, n| @segments[n] = LiveBlock.new(@x + xy[0], @y + xy[1], @color - 0x99000000) }
	end	
	
	def move_left (n = MOVE_SPEED)
		n.times { @x -=1; @segments.each {|seg| seg.x -= 1} unless @segments.any? { |seg| cell(seg.x-1, seg.y).filled? || seg.x <= 0} }		
	end
	
	def move_right (n = MOVE_SPEED)
		n.times {@x += 1; @segments.each {|seg| seg.x += 1} unless @segments.any? {|seg| cell(seg.x+1, seg.y).filled? || seg.x >= Grid::Width - 1}}
	end
	
	def rotation_safe?
		coordinate_array = [ [], [], [], [] ]
		transform_matrix.each_with_index  do |xy, n|
			coordinate_array[n][0] = @x + xy[0]
			coordinate_array[n][1] = @y + xy[1]
    end
			
		if coordinate_array.any? { |x, y| cell(x, y).filled? || x >= Grid::Width || x < 0 || y >= Grid::Height }
			return false
		else
			true
		end
	end
	
	def rotate
		if rotation_safe?
			transform_matrix!
			create_segments	
		end
	end
	
	def fall (speed = MOVE_SPEED)
		@@fall_counter +=1
		if @@fall_counter == 20
			@@fall_counter = 0
			speed.times{
				@y += 1
				@segments.each {|seg| seg.y += 1}
				if @segments.any? {|seg| seg.y >= Grid::Height-1 || @@cells[seg.x][seg.y+1].filled?}
					crash
					break
				end}
		end
	end
	
	def plummet
		@@fall_counter = 19
		fall(5)
	end
	
	def crash
		@segments.each {|seg| seg.die}
		(0...Grid::Height).each {|n| check_for_deletion(n)}
		$window.game_over if game_over?
		$window.next_block
	end
	
	def draw
		@segments.each {|seg| seg.draw}	
	end
end

class LiveBlock < GameObject

	def initialize(x, y, color)
		super x, y, color
	end

	def die
		cell(@x, @y).fill(@color+0x99000000)
		end
	end

class PreviewBlock <FallingBlock

	def initialize
		@x, @y = Grid::Width/2, Grid::Height + 2
		@color = @@colors[rand(0..4)]
		@matrix = @@shapes.shuffle.first
		@segments = []
		
		create_segments		
	end
	
	def next
		$window.falling_block = FallingBlock.new(@matrix, @color)
		@color = @@colors[rand(0..4)]
		@matrix = @@shapes.shuffle.first
		create_segments		
	end
	
	def draw
		@segments.each {|seg| seg.draw}
		@@cells.each {|columns| columns.each {|cell| cell.draw if cell.filled?}}
	end

end
	
class GameWindow < Gosu::Window

	attr_accessor	:falling_block, :score, :song

	def initialize
		super Width, Height, false
		$window = self
		@grid = Grid.new
		@falling_block = FallingBlock.new
		@preview_block = PreviewBlock.new
		@song = Gosu::Song.new(self, "tetris.wav")
		@song.play(true)
		@game_over = false
		@game_over_message = Gosu::Font.new(self, "Helvetica", 100)
		@score_font = Gosu::Font.new(self, "Consolas", 50)
		@score = 0
	end
	
	def draw
		if @game_over
			@game_over_message.draw("Game Over", Width/4, Height/2, 1)
		else
			@preview_block.draw
			@falling_block.draw
			@grid.draw
			@score_font.draw("Score", Grid::Left_Edge/2, Grid::Top_Edge, 1)
			@score_font.draw(@score.to_s, Grid::Left_Edge/2, Grid::Top_Edge + 55, 1)
		end
	end
	
	def next_block
		@preview_block.next
	end
	
	def game_over
		@song.stop
		@game_over = true
	end
	
	def reset
		@grid = Grid.new
		@falling_block = FallingBlock.new
		@preview_block = PreviewBlock.new
		@song.play(true)
		@game_over = false
		@score = 0
	end
	
	def button_down(id)
	
		if @game_over
			if id == Gosu::KbReturn
				$window.reset
			end
		else
			case
				when id==(Gosu::KbLeft)
					@falling_block.move_left
				when id==(Gosu::KbRight)
					@falling_block.move_right
				when id==(Gosu::KbDown)
					@falling_block.plummet
				when id ==(Gosu::KbUp)
					@falling_block.rotate
			end
		end
	end
		
	def update				
		@falling_block.fall	unless @game_over
	end	

end

window = GameWindow.new
window.show