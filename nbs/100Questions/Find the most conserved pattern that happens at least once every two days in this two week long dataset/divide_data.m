function seven_two_day_chunks = divide_data(house1)
twoDaysLength = 20000;
stPoint = 20000;
numOfDays = 7;
seven_two_day_chunks = [house1(stPoint:stPoint + twoDaysLength)];
for i = 1:numOfDays-1
    stPoint = stPoint + twoDaysLength;
    seven_two_day_chunks = [seven_two_day_chunks;nan;house1(stPoint:(stPoint + twoDaysLength))];
    
end

end