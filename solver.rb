#!/usr/bin/env ruby
# encoding: utf-8

require 'pp'

class SudokuSolver
  attr_reader :grid

  def initialize()
    @grid = Grid.new()
    @steps = []
  end

  def solve_brute_force
    cell_index, cell = @grid.first
    i=0
    until cell.nil? || !@grid.first_not_finished
      cell_value = cell.increment
      #puts @grid.cell_position(cell_index)+":"+cell_value.to_s
      unless cell_value == false
        if @grid.value_allowed?(cell_index, cell_value)
          @steps << @grid.cell_position(cell_index)+"="+cell_value.to_s
          puts @steps.join("=>")
          i+=1
          cell.increment!
          cell_index, cell = @grid.next(cell_index)
        else
          cell.increment!
        end
      else
        if @steps.size>1 && @grid.first_not_finished
          puts "\n\n-----false of : [#{@grid.cell_position(cell_index)},#{cell_value}]"+@steps.join("=>")+"\n\n"
          puts @grid.to_s
        end
        cell.empty!
        cell_index, cell = @grid.pred(cell_index)
      end
    end
    i
  end

  def set_cell_value(cell_index, value, prefix='')
    cell = @grid.cell_at(cell_index)
    cell.set_value(value)
    @grid.unset_left_value_of_cell_index(cell_index, value)
    @steps << prefix+@grid.cell_position(cell_index)+"="+value.to_s
    puts @steps.join("->")
    puts @grid.to_s
  end

  def hidden_single
    #按照摒除法Hidden Single处理区块
    updated = true
    while updated
      updated = false
      #挨个数字查找
      [*1..@grid.size].each { |test_value|
        [*0..@grid.size-1].each { |block_index|
          min_row, max_row, min_column, max_column = @grid.block_range(block_index)
          #puts "test block_index:#{block_index} of #{test_value}"

          #区块中不存在test_value
          unless @grid.subgrid_contains_value?(min_row, min_column, test_value)
            test_array = []
            (min_row..max_row).each { |row_index|
              (min_column..max_column).each { |column_index|
                cell_index = @grid.rc_to_index(row_index, column_index)
                cell = @grid.cell_at(cell_index)
                if cell.empty? && @grid.value_allowed?(cell_index, test_value)
                  test_array << cell_index
                end
              }
            }

            if test_array.size == 1
              #puts test_array
              set_cell_value(test_array[0], test_value, "["+__method__.to_s+"]")
              updated = true
            elsif test_array.size == 0 && @grid.first_not_finished
              puts "\n\n-----false of : [#{test_value}], block:[#{block_index}]"+@steps.join("=>")+"\n\n"
              puts @grid.to_s
              exit
            end
          end
        }
      }
    end
    updated
  end

  def only_one
    #逐个按照行、列、单元格捞出唯一值
    updated = true
    while updated
      updated = false
      (0..(@grid.size*@grid.size-1)).each do |index|
        cell_index, cell = index, @grid.cell_at(index)
        if cell.empty?
          not_allow_values = @grid.all_exist_value_of_cell(cell_index)
          if not_allow_values.size==8
            value = ([*1..@grid.size] - not_allow_values)[0]
            set_cell_value(cell_index, value, "["+__method__.to_s+"]")
            updated = true
          elsif not_allow_values.size == 9 && @grid.first_not_finished
            puts "\n\n-----false of : [#{@grid.cell_position(cell_index)}]"+@steps.join("=>")+"\n\n"
            puts @grid.to_s
            exit
          end

          #allow_values = (1..@grid.size).select{|i| @grid.value_allowed?(cell_index, i)}
          #if allow_values.size==1
          #   value = allow_values[0]
        end
      end
    end
    updated
  end

  def only_left_one
    #逐个按照行、列、单元格捞出唯一值
    updated = true
    while updated
      updated = false
      (0..(@grid.size*@grid.size-1)).each do |index|
        cell_index, cell = index, @grid.cell_at(index)
        if cell.empty?
          if cell.left_value.size==1
            value = cell.left_value[0]
            set_cell_value(cell_index, value, "["+__method__.to_s+"]")
            updated = true
          elsif cell.left_value.size==0
            puts "\n\n-----false of : [#{@grid.cell_position(cell_index)}]"+@steps.join("=>")+"\n\n"
            puts @grid.to_s
            exit
          end
        end
      end
    end
    updated
  end

  def solve_mix

    updated = true
    while updated
      #updated = hidden_single || only_one || only_left_one
      updated = hidden_single || only_left_one
    end

    #solve_brute_force

    if @grid.first_not_finished
      puts "not finish"
    else
      puts "finished"
    end

  end

  # Class implements methods for easier manipulation with grid
  class Grid
    attr_reader :size
    attr_reader :sub_size

    def initialize()
      @size = 0
      @sub_size = 0
      @rows = Array.new
    end

    def block_range(block_index)
      min_row = @sub_size*(block_index / @sub_size).to_i + 0
      max_row = @sub_size*(block_index / @sub_size).to_i + (@sub_size - 1)

      min_column = @sub_size*(block_index % @sub_size) + 0
      max_column = @sub_size*(block_index % @sub_size) + (@sub_size - 1)

      [min_row.to_i, max_row.to_i, min_column.to_i, max_column.to_i]
    end

    def index_to_rc(cell_index)
      [cell_index / @size.to_i, cell_index % @size.to_i]
    end

    def rc_to_index(row_index, column_index)
      row_index * @size.to_i + column_index
    end

    def cell_at(cell_index)
      @rows[cell_index / @size.to_i][cell_index % @size.to_i]
    end

    def cell_at_rc(row_index, column_index)
      @rows[row_index][column_index]
    end

    def cell_position(cell_index)
      ('a'.ord.to_i+cell_index / @size.to_i).chr.to_s+(1+cell_index % @size.to_i).to_s
    end

    def load_from_file(file_path)
      File.open(file_path, 'r').each_line do |line|
        if line.split.size > 8 #有空格
          arr = line.split.collect do |value|
            value = value.to_i
            if value == 0
              Cell.new(nil, 9)
            elsif value >0 && value<10
              Cell.new(value, 9, true)
            end
          end
        else
          #无空格
          arr = line.each_byte.collect do |value|
            if value.chr>='0' #
              value = value.chr.to_i
              if value == 0
                Cell.new(nil, 9)
              elsif value >0 && value<10
                Cell.new(value, 9, true)
              end
            end
          end
        end
        @rows.push(
            arr
        )
      end
      @size = @rows.count
      @sub_size = Math.sqrt(@size)
      self.each { |cell_index, cell|
        if cell.value
          unset_left_value_of_cell_index(cell_index, cell.value)
        end
      }
    end

    def each
      (0..(@size*@size-1)).each do |index|
        yield index, cell_at(index)
      end
      nil
    end

    def first_not_finished
      (0..(@size*@size-1)).each do |index|
        return index, cell_at(index) if cell_at(index).empty?
      end
      nil
    end

    def first
      (0..(@size*@size-1)).each do |index|
        return index, cell_at(index) unless cell_at(index).predefined?
      end
      nil
    end

    def next(cell_index)
      (cell_index+1..(@size*@size-1)).each do |index|
        return index, cell_at(index) unless cell_at(index).predefined?
      end
      return nil, nil
    end

    def pred(cell_index)
      (0..cell_index-1).reverse_each do |index|
        return index, cell_at(index) unless cell_at(index).predefined?
      end
      return nil, nil
    end

    def unset_left_value_of_cell_index(cell_index, value)
      row_index = cell_index / @size.to_i
      column_index = cell_index % @size.to_i
      row_unset_left_value_of(row_index, value)
      column_unset_left_value_of(column_index, value)
      subgrid_unset_left_value_of(row_index, column_index, value)
    end

    def row_unset_left_value_of(row_index,value)
      (0..@size-1).each do |column_index|
        @rows[row_index][column_index].unset_left_value(value)
      end
    end

    def column_unset_left_value_of(column_index,value)
      (0..@size-1).map do |row_index|
        @rows[row_index][column_index].unset_left_value(value)
      end
    end

    def subgrid_unset_left_value_of(row_index, column_index,value)
      start_row_index = row_index - (row_index % @sub_size)
      start_column_index = column_index - (column_index % @sub_size)
      end_row_index = start_row_index + @sub_size - 1
      end_column_index = start_column_index + @sub_size - 1
      @rows[start_row_index..end_row_index].each do |row|
        row[start_column_index..end_column_index].each do |cell|
          cell.unset_left_value(value)
        end
      end
    end

    def value_allowed?(cell_index, value)
      row_index = cell_index / @size.to_i
      column_index = cell_index % @size.to_i
      return false if row_contains_value?(row_index, value)
      return false if column_contains_value?(column_index, value)
      return false if subgrid_contains_value?(row_index, column_index, value)
      true
    end

    def value_allowed_rc?(row_index, column_index, value)
      return false if row_contains_value?(row_index, value)
      return false if column_contains_value?(column_index, value)
      return false if subgrid_contains_value?(row_index, column_index, value)
      true
    end

    #返回跟一个cell相关的行列单元格都相关的数字组合
    def all_exist_value_of_cell(cell_index)
      row_index = cell_index / @size.to_i
      column_index = cell_index % @size.to_i
      return (row_values(row_index) | column_values(column_index) | subgrid_values(row_index, column_index)).uniq.sort
    end

    def row_values(row_index)
      values = []
      (0..@size-1).each do |column_index|
        values << @rows[row_index][column_index].value if @rows[row_index][column_index].value
      end
      values
    end

    def column_values(column_index)
      values = []
      (0..@size-1).map do |row_index|
        values << @rows[row_index][column_index].value if @rows[row_index][column_index].value
      end
      values
    end

    def subgrid_values(row_index, column_index)
      values = []
      start_row_index = row_index - (row_index % @sub_size)
      start_column_index = column_index - (column_index % @sub_size)
      end_row_index = start_row_index + @sub_size - 1
      end_column_index = start_column_index + @sub_size - 1
      @rows[start_row_index..end_row_index].each do |row|
        row[start_column_index..end_column_index].each do |cell|
          values << cell.value if cell.value
        end
      end
      values
    end

    def row_contains_value?(row_index, value)
      (0..@size-1).each do |column_index|
        return true if @rows[row_index][column_index].value == value
      end
      false
    end

    def column_contains_value?(column_index, value)
      (0..@size-1).each do |row_index|
        return true if @rows[row_index][column_index].value == value
      end
      false
    end

    def subgrid_contains_value?(row_index, column_index, value)
      start_row_index = row_index - (row_index % @sub_size)
      start_column_index = column_index - (column_index % @sub_size)
      end_row_index = start_row_index + @sub_size - 1
      end_column_index = start_column_index + @sub_size - 1
      @rows[start_row_index..end_row_index].each do |row|
        row[start_column_index..end_column_index].each do |cell|
          return true if cell.value == value
        end
      end
      false
    end

    def left_value_to_s
      output = "========================left_value_to_s=======================\n"

      i = 'a'
      @rows.each do |row|
        cindex = 1
        row.each { |cell|
          if cell
            output += "#{i.chr.to_s}#{cindex} : "
            output += cell.left_value.join(',')
            output += "\n"
            cindex += 1
          end
        }
        i = i.ord.to_i + 1
      end
      output += '     '+(1..9).map { |i| '---' }.join('-') + "\n"
      output
    end

    def to_s
      output = "=========================to_s======================\n"
      output += '      '+(1..9).map { |i| i.to_s }.join('   ') + "\n"

      i = 'a'
      @rows.each do |row|
        output += '     '+(1..9).map { |i| '---' }.join('-') + "\n" if i.chr.to_s=='a' || i.chr.to_s=='d' || i.chr.to_s=='g'
        output += i.chr.to_s
        output += ":  | "
        output += row.collect { |column| column.to_s }.join(' | ')
        output += " | " if i.chr.to_s=='i'
        output += "\n"
        i = i.ord.to_i + 1
      end
      output += '     '+(1..9).map { |i| '---' }.join('-') + "\n"
      output
    end

    # Class represents one cell in sudoku grid
    class Cell
      attr_accessor :value
      attr_reader :predefined
      attr_reader :left_value #可能的数字数组

      def initialize(value, max_value = 9, predefined = false)
        @max_value = max_value
        @value = value
        @predefined = predefined
        @left_value = [*1..9]
        @left_value = [value] if value
      end

      def predefined?
        @predefined
      end

      def empty?
        @value.nil? ? true : false
      end

      def empty!
        @value = nil
      end

      def to_s
        #empty? ? '?' : @value.to_s
        empty? ? ' ' : @value.to_s
      end

      def increment
        if empty?
          1
        else
          if @value == @max_value
            false
          else
            @value.next
          end
        end
      end

      def set_value(value)
        @value = value
      end

      def unset_left_value(value)
        @left_value -= [value]
      end

      def increment!
        @value = self.increment
      end
    end

  end

end

sudoku = SudokuSolver.new()
sudoku.grid.load_from_file('sudoku.txt')
raw_grid = sudoku.grid.to_s
puts raw_grid
#puts sudoku.grid.all_exist_value_of_cell(0)
sudoku.solve_mix
#puts "finished!"
puts raw_grid, sudoku.grid.to_s
puts sudoku.grid.left_value_to_s