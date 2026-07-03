# Borzoi

# eventually I'll make a tool for one line Borzoi calls with ARGV

# work in progress

borzoi_dog = <<~ART
  ,.                            
  '/' _            ,..--..      
    `-b'\......''`-'' __` `.     
      _''           _/''''''     
    ,'--._,_______,/            
    ,/,' ,/''  | ||/             
    /|' ,'./  ./|/'/             
    |' <,/'  ,|/'|,|             
            ''''''     
ART

loop do
  puts borzoi_dog
  puts '
  Borzoi CLI:
  1 -> add a function to the registry
  2 -> have Borzoi Parse a file
  3 -> documentation
  '
  input = gets.chomp
  case input
  when '1' then 'append'
  when '2' then 'parse'
  when '3'
  else redo
  end
end
# Honestly I realized something:
# I have no clue what Borzoi is going to output
