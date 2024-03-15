# inverts signs_lib font to black on transparent background
img_path=./
#img_results=./converted
#mkdir -p $img_results
for img in ${img_path}/*;
    do 
#    convert -negate $img ${img_results}/${img#./*};
	convert $img -background white -alpha remove -alpha off -negate -transparent white $img
done

