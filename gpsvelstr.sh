#!/bin/bash

##  the logfile (can be set later on). By default it is set to 'stderr'.
LOGFILE=stderr

##  the version
VERSION="gpsvelstr 1.0.10"

##
##  verbosity level for GMT, see http://gmt.soest.hawaii.edu/doc/5.1.0/gmt.html#v-full
##
GMTVRB=n

##
##  if LOGFILE is 'stderr' write message to STDERR. Else write it to both
##+ STDERR and LOGFILE
##
echoerr () { 
    [ "$LOGFILE" == "stderr" ] && { echo "$@" 1>&2 ; } || \
    { echo "$@" | tee -a $LOGFILE 1>&2; }
}

##
##  if LOGFILE is 'stderr' write message to /dev/null (i.e. nowhere). Else write
##+ it to LOGFILE
##
echolog () { [ "$LOGFILE" != "stderr" ] && { echo "$@" 1>>$LOGFILE; } }

check_status () {
    if ! test $1 -eq 0 ; then
        echoerr "[ERROR] Command failed; returning..."
        exit 1
    fi
}

##
##  Function to check the validity of an input file. The function expects two
##+ arguments:
##  1. the filename of the file to check (including path and everything)
##  2. the number of fields the file should have (i.e. for horizontal velocity
##+    files, this should be '10').
##
##  The function will check:
##  1. If the file exists
##  3. If all the lines within the file have the same number of fields, and
##  2. If the number of fields within the file are $2
##
##  If anything goes wrong, the function will return 1, else it will return 0.
##
check_inputfl ()
{
    local file=$1
    local fields=$2
    if ! test -f $file ; then
        echoerr "[ERROR] File \"$file\" does not exist."
        return 1
    fi
    if test $(cat $file | awk '{print NF}' | uniq | wc -l) -ne 1 ; then
        echoerr "[ERROR] File \"$file\" contains inconsistent lines"
        echoerr "        (number of fields is not always the same)."
        return 1
    fi
    if test $(cat $file | awk '{print NF}' | uniq) -ne $fields ; then
        echoerr "[ERROR] File \"$file\" should contain ten (10) fields!"
        return 1
    fi
    return 0
}

##
##  help function
##
function help {
    echo "/******************************************************************************/"
    echo " Program Name : gpsvelstr.sh"
    echo " Version : ${VERSION}"
    echo " Purpose : Plot velocities and strains"
    echo " Default param file: default-param"
    echo " Usage   :gpsvelstr.sh -r west east south north | -topo | -o [output] | -jpg "
    echo " Switches: "
    echo "           -r      [:= region] region to plot west east south north (default Greece)"
    echo "                   use: -r west east south north projscale frame"
    echo "           -mt     [:= map title] title map default none use quotes"
    echo "           -topo   [:= update catalogue] title map default none use quotes"
    echo "           -faults [:= faults] plot NOA fault database"
    echo ""
    echo "/*** PLOT VELOCITIES **********************************************************/"
    echo "           -vhor (input_file)[:=horizontal velocities]. More than one input files are allowed. "
    echo "                 Different input files will be drawn with different colors."
    echo "           -vver (input_file)[:=vertical velocities]  "
# echo "           -valign (gmt_file) plot tranverse & along velocities"
    echo "           -vsc              [:=velocity scale] change valocity scale default 0.05"
    echo ""
    echo "/*** PLOT STRAINS **********************************************************/"
    echo "           -str (input file)[:= strains] Plot strain rates "
# echo "           -rot (input file)[:= rots] Plot rotational rates "
# echo "           -dil [:=dilatation] Plot dilatation and principal axes"
    echo "           -strsc           [:=strain scale]"
# echo ""
    echo ""
    echo "/*** OTHER OPRTIONS ************************************************************/"
    echo "           -o    [:= output] name of output files"
    echo "           -l    [:=labels] plot labels"
    echo "           -leg  [:=legend] insert legends"
    echo "           -logo [:=logo] plot logo"
    echo "           -jpg : convert eps file to jpg"
    echo "           -h    [:= help] help menu"
    echo ""
    echo " Exit Status:    1 -> help message or error"
    echo " Exit Status: >= 0 -> sucesseful exit"
    echo ""
    echo "run: ./gpsvelstr.sh -topo -jpg "
    echo "/******************************************************************************/"
    exit 0
}

## 
##  GMT parameters
##
gmt gmtset MAP_FRAME_TYPE fancy
gmt gmtset PS_PAGE_ORIENTATION portrait
gmt gmtset FONT_ANNOT_PRIMARY 10 \
FONT_LABEL 10 \
MAP_FRAME_WIDTH 0.12c \
FONT_TITLE 18p,Palatino-BoldItalic

##
##  Pre-defined parameters for bash script. Deafault (map) parametrs will plot
##+ REGION="greece"
##
TOPOGRAPHY=0
FAULTS=0
LABELS=0
LOGO=0
OUTJPG=0
LEGEND=0
VHORIZONTAL=0
VVERTICAL=0
#VALIGN=0
STRAIN=0
STRROT=0

##
##  The file "default-param" is neccesary. Check that it exists.
##
if ! test -f "default-param"; then
    echoerr "[ERROR] default-param file does not exist."
    exit 1
else
    source default-param
fi

##
##  Array of horizontal velocity files. This starts off empty and will be
##+ filled up with all files specified as arguments to "-vhor".
##
declare -a horvelfls=()
##
##  Same (as above) for vertical velocities.
##
declare -a vervelfls=()

##
##  GMT color list. Each seperate file will be ploted with a different color.
##  The array must be at least as large as the number of different input files.
##
declare -a gmtcolorlist=("orange" "blue" "red" "green" "khaki" "yellow" "orange")

##
## get command line arguments
##
if test "$#" == "0" ; then help ; fi

while [ $# -gt 0 ] ; do
    case "$1" in
        -r)
        west=$2
        east=$3
        south=$4
        north=$5
        projscale=$6
        frame=$7
        #REGION=$2
        shift 7
        ;;
        -mt)
        maptitle=$2
        shift 2
        ;;
        -vhor)  ## more than one input files are accepted
        shift
        ##  keep on reading files until we reach an argument starting with '-'.
        ##+ Files are added to the 'horvelfls' array.
        while [ $# -gt 0 ] && [ "${1:0:1}" != "-" ] ; do
            horvelfls+=("$1")
            shift
        done
        VHORIZONTAL=1
        ;;
        -vver)
        shift
        ##  keep on reading files until we reach an argument starting with '-'.
        ##+ Files are added to the 'vervelfls' array.
        while [ $# -gt 0 ] && [ "${1:0:1}" != "-" ] ; do
            vervelfls+=("$1")
            shift
        done
        VVERTICAL=1
        ;;
#     -valign)
#       pth2valong=${pth2inptf}/${2}_along.vel
#       pth2vtranv=${pth2inptf}/${2}_tranv.vel
#       VALIGN=1
#       shift
#       shift
#       ;;
        -vsc)
        VSC=$2
        shift 2
        ;;
        -str)
        pth2strain=${pth2inptf}/${2}
        STRAIN=1
        shift 2
        ;;
        -strsc)
        STRSC=$2
        shift 2
        ;;
        -rot)
        pth2strain=${pth2inptf}/${2}
        STRROT=1
        shift 2
        ;;
        -topo)
# switch topo not used in server!
        TOPOGRAPHY=1
        shift
        ;;
        -faults)
        FAULTS=1
        shift
        ;;  
        -o)
        outfile=${2}.eps
        out_jpg=${2}.jpg
        shift 2
        ;;
        -l)
        LABELS=1
        shift
        ;;
        -leg)
        LEGEND=1
        shift
        ;;
        -logo)
        LOGO=1
        shift
        ;;
        -jpg)
        OUTJPG=1
        shift
        ;;
        -h)
        help
        ;;
    esac
done

##
##  resolve, check and set parameters/variables based on the command line
##+ arguments
##

##  check dems
if test "$TOPOGRAPHY" -eq 1 ; then
    if ! test -f $inputTopoB ; then
        echoerr "[WARNING] grd file for topography toes not exist, var turn to coastline"
        TOPOGRAPHY=0
    fi
fi

##  check input files
if test "$VHORIZONTAL" -eq 1 ; then
    for j in "${horvelfls[@]}" ; do check_inputfl $j 10 || exit 1 ; done
    ##  check that we have enough colors to plot all files
    if test ${#horvelfls[@]} -gt ${#gmtcolorlist[@]} ; then
        echoerr "[ERROR] Not enough colors in array \"gmtcolorlist\" to plot"
        echoerr "        all individual velocity files."
        echoerr "        Append more color-names to \"gmtcolorlist\". A list can"
        echoerr "        be found here: https://www.soest.hawaii.edu/gmt/gmt/html/man/gmtcolors.html"
        exit 1
    fi
fi

if test "$VVERTICAL" -eq 1 ; then
    for j in "${vervelfls[@]}" ; do check_inputfl $j 10 || exit 1 ; done
    if test ${#vervelfls[@]} -gt ${#gmtcolorlist[@]} ; then
        echoerr "[ERROR] Not enough colors in array \"gmtcolorlist\" to plot"
        echoerr "        all individual velocity files."
        echoerr "        Append more color-names to \"gmtcolorlist\". A list can"
        echoerr "        be found here: https://www.soest.hawaii.edu/gmt/gmt/html/man/gmtcolors.html"
        exit 1
    fi
fi

if test "$STRAIN" -eq 1 ; then
    if ! test -f $pth2strain ; then
        echoerr "[ERROR] input file $pth2strain does not exist"
        echoerr "        please download it and then use this switch"
        STRAIN=0
        exit 1
    fi
fi

if test "$STRROT" -eq 1 ; then
    if ! test -f $pth2strain ; then
        echoerr "[ERROR] input file $pth2strain does not exist"
        echoerr "        please download it and then use this switch"
        STRROT=0
        exit 1
    fi
fi

##  check NOA FAULT catalogue
if test "$FAULTS" -eq 1 ; then
    if ! test -f $pth2faults ; then
        echoerr "[WARNING] NOA Faults database does not exist"
        echoerr "          please download it and then use this switch"
        FAULTS=0
    fi
fi

##  check LOGO file
if ! test -f "$pth2logos" ; then
    echoerr "[WARNING] Logo file does not exist"
    LOGO=0
fi

##
##  OK. Now we are ready to start to processing ....
##
echo "Starting plotting...."
echo "Output directed to \"$outfile\"."
echo "Error/log messages writeen in \"$LOGFILE\"."

##
##  set region properties; these are default for GREECE REGION
##
gmt gmtset PS_MEDIA 22cx22c
scale="-Lf20/33.5/36:24/100+l+jr"
range="-R$west/$east/$south/$north"
proj="-Jm24/37/1:$projscale"
# logo_pos="BL/6c/-1.5c/DSO[at]ntua"
# logo_pos2="-C16c/15.6c"
# legendc="-Jx1i -R0/8/0/8 -Dx18.5c/12.6c/3.6c/3.5c/BL" 
# maptitle=""

##
##  TOPOGRAPHY
##  If any of the GMT commands fails, then the script will exit with a status
##+ code of '1'.
##
if test "$TOPOGRAPHY" -eq 0 ; then
    #  Plot coastlines only
    gmt psbasemap $range $proj $scale -B$frame:."$maptitle": -P -K > $outfile \
        || { exit 1 ; }
    gmt pscoast -R -J -O -K -W0.25 -G195 -Df -Na -U$logo_pos >> $outfile \
        || { exit 1; }
    #  pscoast -Jm -R -Df -W0.25p,black -G195  -U$logo_pos -K -O -V >> $outfile
    #  psbasemap -R -J -O -K --FONT_ANNOT_PRIMARY=10p $scale --FONT_LABEL=10p >> $outfile
else
    ##  bathymetry
    gmt makecpt -Cgebco.cpt -T-7000/0/150 -Z > $bathcpt || { exit 1; }
    gmt grdimage $inputTopoB $range $proj -C$bathcpt -K > $outfile\
        || { exit 1; }
    gmt pscoast $proj -P $range -Df -Gc -K -O >> $outfile|| { exit 1; }
    ##  land
    gmt makecpt -Cgray.cpt -T-3000/1800/50 -Z > $landcpt|| { exit 1; }
    gmt grdimage $inputTopoL $range $proj -C$landcpt  -K -O >> $outfile \
        || { exit 1; }
    gmt pscoast -R -J -O -K -Q >> $outfile|| { exit 1; }
    ##  coastline
    gmt psbasemap -R -J -O -K -B$frame:."$maptitle":  $scale >> $outfile \
        || { exit 1; }
    gmt pscoast -J -R -Df -W0.25p,black -K  -O -U$logo_pos >> $outfile \
        || { exit 1; }
fi

##
##  plot noa catalogue faults ganas et.al, 2013
##
if test "$FAULTS" -eq 1 ; then
    echo "ploting NOA faults catalogue Ganas et.al, 2013 ..."
    gmt psxy $pth2faults -R -J -O -K  -W.5,204/102/0  >> $outfile
fi

##
##  plot horizontal velocities. Read velocities from input file(s). Each file
##+ will be ploted with a different color based on the "gmtcolor" array.
##  If any of the GMT commands fails, then the script will exit with a status
##+ code of '1'.
##
##  WARNING: gmt5 std must be zero to plot
##
if test "$VHORIZONTAL" -eq 1 ; then
    coloriter=0
    for j in "${horvelfls[@]}" ; do
        ccolor=${gmtcolorlist[$coloriter]}
        echolog "Ploting horizontal velocity file \"$j\" with color \"$ccolor\"."
        awk '{print $3,$2}' $j \
            | gmt psxy -Jm -O -R -Sc0.10c -W0.005c -G${ccolor} -K \
            >> $outfile || { exit 1; }
        awk '{print $3,$2,$7,$5,$8,$6,0,$1}' $j | \
            gmt psvelo -R -J -Se${VSC}/0.95/0 -W.3p,100 -A10p+e -V${GMTVRB} \
            -G${ccolor} -O -K -L >> $outfile || { exit 1; } # 205/133/63.
        awk '{print $3,$2,$7,$5,$8,$6,0,$1}' $j | \
            gmt psvelo -R -J -Se${VSC}/0/0 -W2p,${ccolor} -A10p+e -G${ccolor} \
            -O -K -L -V${GMTVRB} >> $outfile || { exit 1; }  # 205/133/63.
        if test "$LABELS" -eq 1 ; then
            awk '{print $3,$2,9,0,1,"RB",$1}' $j | \
                gmt pstext -Jm -R -Dj0.2c/0.2c -O -K -V \
                >> $outfile || { exit 1; }
        fi
        coloriter=$((coloriter+1))
    done
    ##  scale
    echo "$vsclon $vsclat $vscmagn 0 0 0 0 $vscmagn mm" | \
        gmt psvelo -R -Jm -Se${VSC}/0.95/10 -W2p,blue -A10p+e -Gblack \
        -O -K -L -V${GMTVRB} >> $outfile || { exit 1; }
fi

##
##  plot vertical velocities. Read velocities from input file(s). Each file
##+ will be ploted with a different color based on the "gmtcolor" array.
##  If any of the GMT commands fails, then the script will exit with a status
##+ code of '1'.
##
if test "$VVERTICAL" -eq 1 ; then
    coloriter=0
    for j in "${vervelfls[@]}" ; do
        ccolor=${gmtcolorlist[$coloriter]}
        echolog "Ploting vertical velocity file \"$j\" with color \"$ccolor\"."
        awk '{print $3,$2}' $pth2vver | gmt psxy -Jm -O -R -Sc0.15c -W0.005c \
            -Gwhite -K >> $outfile || { exit 1; }
        awk '{if ($9<0) print $3,$2,0,$9,0,0,0,$1}' $pth2vver | \
            gmt psvelo -R -Jm -Se${VSC}/0.95/0 -W2p,red -A10p+e -Gred \
            -O -K -L -V${GMTVRB} >> $outfile || { exit 1; }
        awk '{if ($9>=0) print $3,$2,0,$9,0,0,0,$1}' $pth2vver | \
            gmt psvelo -R -Jm -Se${VSC}/0.95/0 -W2p,blue -A10p+e -Gblue \
            -O -K -L -V${GMTVRB} >> $outfile || { exit 1; }
        if test "$LABELS" -eq 1 ; then
            awk '{print $3,$2,9,0,1,"RB",$1}' $pth2vhor | \
                gmt pstext -Jm -R -Dj0.2c/0.2c -Gwhite -O -K -V \
                >> $outfile || { exit 1; }
        fi
        coloriter=$((coloriter+1))
    done
    ##  scale
    echo "$vsclon $vsclat 0 $vscmagn  0 0 0 $vscmagn mm" | \
        gmt psvelo -R -Jm -Se$VSC/0.95/10 -W2p,blue -A10p+e -Gblue \
        -O -K -L -V${GMTVRB} >> $outfile || { exit 1; }
fi

##
##  plot strain rate parameters
##
if test "$STRAIN" -eq 1 ; then
    #  compression
    awk '{print $3,$2,0,$6,$8+90}' $pth2strain | gmt psvelo -Jm $range \
        -Sx${STRSC} -L -A10p+e -Gblue -W2p,blue -V${GMTVRB} -K -O>> $outfile
    #  extension
    awk '{print $3,$2,$4,0,$8+90}' $pth2strain | gmt psvelo -Jm $range \
        -Sx${STRSC} -L -A10p+e -Gred -W2p,red -V${GMTVRB} -K -O>> $outfile
    #  
    echo "$strsclon $strsclat 0 -.01 90" | gmt psvelo -Jm $range \
        -Sx${STRSC} -L -A10p+e -Gblue -W2p,blue -V${GMTVRB} -K -O>> $outfile
    echo "$strsclon $strsclat .01 0 90" | gmt psvelo -Jm $range \
        -Sx${STRSC} -L -A10p+e -Gred -W2p,red -V${GMTVRB} -K -O>> $outfile
    echo "$strsclon $strsclat 9 0 1 CB 10 nstrain" | gmt pstext -Jm -R \
        -Dj0c/1c -Gwhite -O -K -V>> $outfile
fi

##
##  plot rotational rates parameters
## if [ "$STRROT" -eq 1 ]
## then
##   awk '{print $3,$2,$10/1000000,$11/1000000}' $pth2strain | gmt psvelo -Jm $range -Sw1/1.e7 -Gred -E0/0/0/10 -L -A0.05/0/0  -V -K -O>> $outfile
## fi

##
##  plot legend
##
if test "$LEGEND" -eq 1 ; then
    gmt pslegend .legend ${legendc} -C0.1c/0.1c -L1.3 -O -K >> $outfile || { exit 1; }
fi

##
##  plot logo dso
##
if test "$LOGO" -eq 1 ; then
    gmt psimage $pth2logos -O $logo_pos2 -W1.1c -F0.4  -K >>$outfile || { exit 1; }
fi

##
##  close eps file (dummy)
##
echo "9999 9999" | gmt psxy -J -R  -O >> $outfile

##
##  Convert to jpg format
##
if test "$OUTJPG" -eq 1 ; then
    gs -sDEVICE=jpeg -dJPEGQ=100 -dNOPAUSE -dBATCH -dSAFER -r300 \
    -sOutputFile=$out_jpg $outfile
fi

##  remove tmp files
{
rm .legend 2>/dev/null
rm *cpt 2>/dev/null
} 2>/dev/null
 
##  NOA FAULTS reference
##  Ganas Athanassios, Oikonomou Athanassia I., and Tsimi Christina, 2013. NOAFAULTS: a digital database for active faults in Greece. Bulletin of
##  the Geological Society of Greece, vol. XLVII and Proceedings of the 13th International Congress, Chania, Sept. 2013.
##  historic eq papazachos reference

exit 0
