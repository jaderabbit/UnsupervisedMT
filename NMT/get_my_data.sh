# Copyright (c) 2018-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the license found in the
# LICENSE file in the root directory of this source tree.
#
SOURCE=en
TARGET=zu
MONO_SRC=mono
VALID=enzu_parallel.dev
TEST=enzu_parallel.test
set -e

#
# Data preprocessing configuration
#

# We need to limit the number of monolingual sentences for each language
N_MONO=100000    # number of monolingual sentences for each language
CODES=60000      # number of BPE codes
N_THREADS=48     # number of threads in data preprocessing
N_EPOCHS=10      # number of fastText epochs



# main paths
UMT_PATH=$PWD
TOOLS_PATH=$PWD/tools
DATA_PATH=$PWD/data
MONO_PATH=$DATA_PATH/mono
PARA_PATH=$DATA_PATH/para

# create paths
mkdir -p $TOOLS_PATH
mkdir -p $DATA_PATH
mkdir -p $MONO_PATH
mkdir -p $PARA_PATH

# moses
MOSES=$TOOLS_PATH/mosesdecoder
TOKENIZER=$MOSES/scripts/tokenizer/tokenizer.perl
NORM_PUNC=$MOSES/scripts/tokenizer/normalize-punctuation.perl
INPUT_FROM_SGM=$MOSES/scripts/ems/support/input-from-sgm.perl
REM_NON_PRINT_CHAR=$MOSES/scripts/tokenizer/remove-non-printing-char.perl

# fastBPE
FASTBPE_DIR=$TOOLS_PATH/fastBPE
FASTBPE=$FASTBPE_DIR/fast

# fastText
FASTTEXT_DIR=$TOOLS_PATH/fastText
FASTTEXT=$FASTTEXT_DIR/fasttext

# files full paths
SRC_RAW=$MONO_PATH/$MONO_SRC.$SOURCE
TGT_RAW=$MONO_PATH/$MONO_SRC.$TARGET
SRC_TOK=$MONO_PATH/$MONO_SRC.$SOURCE.tok
TGT_TOK=$MONO_PATH/$MONO_SRC.$TARGET.tok
BPE_CODES=$MONO_PATH/bpe_codes
CONCAT_BPE=$MONO_PATH/all.$SOURCE-$TARGET.$CODES
SRC_VOCAB=$MONO_PATH/vocab.$SOURCE.$CODES
TGT_VOCAB=$MONO_PATH/vocab.$TARGET.$CODES
FULL_VOCAB=$MONO_PATH/vocab.$SOURCE-$TARGET.$CODES

# Datasets
# TODO: Check if should be full source
SRC_VALID=$PARA_PATH/$VALID.$SOURCE
TGT_VALID=$PARA_PATH/$VALID.$TARGET
SRC_TEST=$PARA_PATH/$TEST.$SOURCE
TGT_TEST=$PARA_PATH/$TEST.$TARGET



#
# Download and install tools
#

# Download Moses
cd $TOOLS_PATH
if [ ! -d "$MOSES" ]; then
  echo "Cloning Moses from GitHub repository..."
  git clone https://github.com/moses-smt/mosesdecoder.git
fi
echo "Moses found in: $MOSES"

# Download fastBPE
cd $TOOLS_PATH
if [ ! -d "$FASTBPE_DIR" ]; then
  echo "Cloning fastBPE from GitHub repository..."
  git clone https://github.com/glample/fastBPE
fi
echo "fastBPE found in: $FASTBPE_DIR"

# Compile fastBPE
cd $TOOLS_PATH
if [ ! -f "$FASTBPE" ]; then
  echo "Compiling fastBPE..."
  cd $FASTBPE_DIR
  g++ -std=c++11 -pthread -O3 fast.cc -o fast
fi
echo "fastBPE compiled in: $FASTBPE"

# Download fastText
cd $TOOLS_PATH
if [ ! -d "$FASTTEXT_DIR" ]; then
  echo "Cloning fastText from GitHub repository..."
  git clone https://github.com/facebookresearch/fastText.git
fi
echo "fastText found in: $FASTTEXT_DIR"

# Compile fastText
cd $TOOLS_PATH
if [ ! -f "$FASTTEXT" ]; then
  echo "Compiling fastText..."
  cd $FASTTEXT_DIR
  make
fi
echo "fastText compiled in: $FASTTEXT"

#
# Download monolingual data
#

cd $MONO_PATH
MONO_ENGLISH=http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2007.en.shuffled.gz
MONO_ZULU=https://github.com/LauraMartinus/ukuxhumana/raw/master/leipzig/web_2013_100K_mono.zu
echo "Downloading English files..."
if [ ! -f $MONO_SRC.$SOURCE ]; then
    wget -c $MONO_ENGLISH
fi

echo "Downloading $TARGET files..."
if [ ! -f $MONO_SRC.$TARGET ]; then
    wget -c $MONO_ZULU  --output-document $MONO_SRC.$TARGET
    wget -c https://github.com/LauraMartinus/ukuxhumana/raw/master/clean/en_zu/enzu_parallel.dev.zu
    wget -c https://github.com/LauraMartinus/ukuxhumana/raw/master/clean/en_zu/enzu_parallel.test.zu
fi

# Files already decompressed
for FILENAME in news*gz; do
  OUTPUT="${FILENAME::-3}"
  if [ ! -f "$OUTPUT" ]; then
    echo "Decompressing $FILENAME..."
    gunzip -k $FILENAME
    mv news.2007.en.shuffled mono.en
  else
    echo "$OUTPUT already decompressed."
  fi
done

# check number of lines
if ! [[ "$(wc -l < $SRC_RAW)" -eq "$N_MONO" ]]; then 
    echo "ERROR: Number of lines doesn't match! Be sure you have $N_MONO sentences in your EN monolingual data."; 
    echo "Truncating file...";
    sed -i '100001,$ d' $SRC_RAW 
fi
if ! [[ "$(wc -l < $TGT_RAW)" -eq "$N_MONO" ]]; then 
    echo "ERROR: Number of lines doesn't match! Be sure you have $N_MONO sentences in your ZU monolingual data."; 
    echo "Truncating file...";
    sed -i '100001,$ d' $TGT_RAW
fi

# tokenize data
if ! [[ -f "$SRC_TOK" && -f "$TGT_TOK" ]]; then
  echo "Tokenize monolingual data..."
  cat $SRC_RAW | $NORM_PUNC -l en | $TOKENIZER -l en -no-escape -threads $N_THREADS > $SRC_TOK
  cat $TGT_RAW | $NORM_PUNC -l zu | $TOKENIZER -l zu -no-escape -threads $N_THREADS > $TGT_TOK
fi
echo "EN monolingual data tokenized in: $SRC_TOK"
echo "ZU monolingual data tokenized in: $TGT_TOK"


# learn BPE codes
if [ ! -f "$BPE_CODES" ]; then
  echo "Learning BPE codes..."
  $FASTBPE learnbpe $CODES $SRC_TOK $TGT_TOK > $BPE_CODES
fi
echo "BPE learned in $BPE_CODES"


# apply BPE codes
if ! [[ -f "$SRC_TOK.$CODES" && -f "$TGT_TOK.$CODES" ]]; then
  echo "Applying BPE codes..."
  $FASTBPE applybpe $SRC_TOK.$CODES $SRC_TOK $BPE_CODES
  $FASTBPE applybpe $TGT_TOK.$CODES $TGT_TOK $BPE_CODES
fi
echo "BPE codes applied to EN in: $SRC_TOK.$CODES"
echo "BPE codes applied to ZU in: $TGT_TOK.$CODES"

# extract vocabulary
if ! [[ -f "$SRC_VOCAB" && -f "$TGT_VOCAB" && -f "$FULL_VOCAB" ]]; then
  echo "Extracting vocabulary..."
  $FASTBPE getvocab $SRC_TOK.$CODES > $SRC_VOCAB
  $FASTBPE getvocab $TGT_TOK.$CODES > $TGT_VOCAB
  $FASTBPE getvocab $SRC_TOK.$CODES $TGT_TOK.$CODES > $FULL_VOCAB
fi
echo "EN vocab in: $SRC_VOCAB"
echo "ZU vocab in: $TGT_VOCAB"
echo "Full vocab in: $FULL_VOCAB"

# binarize data
if ! [[ -f "$SRC_TOK.$CODES.pth" && -f "$TGT_TOK.$CODES.pth" ]]; then
  echo "Binarizing data..."
  $UMT_PATH/preprocess.py $FULL_VOCAB $SRC_TOK.$CODES
  $UMT_PATH/preprocess.py $FULL_VOCAB $TGT_TOK.$CODES
fi
echo "EN binarized data in: $SRC_TOK.$CODES.pth"
echo "ZU binarized data in: $TGT_TOK.$CODES.pth"


#
# Download parallel data (for evaluation only)
#

cd $PARA_PATH

echo "Downloading parallel data..."
wget -c https://github.com/LauraMartinus/ukuxhumana/raw/master/clean/en_zu/enzu_parallel.dev.en
wget -c https://github.com/LauraMartinus/ukuxhumana/raw/master/clean/en_zu/enzu_parallel.dev.zu

wget -c https://github.com/LauraMartinus/ukuxhumana/raw/master/clean/en_zu/enzu_parallel.test.en
wget -c https://github.com/LauraMartinus/ukuxhumana/raw/master/clean/en_zu/enzu_parallel.test.zu


echo "Extracting parallel data..."

# check valid and test files are here
if ! [[ -f "$SRC_VALID" ]]; then echo "$SRC_VALID is not found!"; exit; fi
if ! [[ -f "$TGT_VALID" ]]; then echo "$TGT_VALID is not found!"; exit; fi
if ! [[ -f "$SRC_TEST" ]]; then echo "$SRC_TEST is not found!"; exit; fi
if ! [[ -f "$TGT_TEST" ]]; then echo "$TGT_TEST is not found!"; exit; fi

echo "Tokenizing valid and test data..."
cat $SRC_VALID | $NORM_PUNC -l en | $REM_NON_PRINT_CHAR | $TOKENIZER -l en -no-escape -threads $N_THREADS > $SRC_VALID.tmp
cat $TGT_VALID | $NORM_PUNC -l zu | $REM_NON_PRINT_CHAR | $TOKENIZER -l zu -no-escape -threads $N_THREADS > $TGT_VALID.tmp
cat $SRC_TEST | $NORM_PUNC -l en | $REM_NON_PRINT_CHAR | $TOKENIZER -l en -no-escape -threads $N_THREADS > $SRC_TEST.tmp
cat $TGT_TEST | $NORM_PUNC -l zu | $REM_NON_PRINT_CHAR | $TOKENIZER -l zu -no-escape -threads $N_THREADS > $TGT_TEST.tmp

mv $SRC_VALID.tmp $SRC_VALID
mv $TGT_VALID.tmp $TGT_VALID
mv $SRC_TEST.tmp $SRC_TEST
mv $TGT_TEST.tmp $TGT_TEST


echo "Applying BPE to valid and test files..."
$FASTBPE applybpe $SRC_VALID.$CODES $SRC_VALID $BPE_CODES $SRC_VOCAB
$FASTBPE applybpe $TGT_VALID.$CODES $TGT_VALID $BPE_CODES $TGT_VOCAB
$FASTBPE applybpe $SRC_TEST.$CODES $SRC_TEST $BPE_CODES $SRC_VOCAB
$FASTBPE applybpe $TGT_TEST.$CODES $TGT_TEST $BPE_CODES $TGT_VOCAB

echo "Binarizing data..."
rm -f $SRC_VALID.$CODES.pth $TGT_VALID.$CODES.pth $SRC_TEST.$CODES.pth $TGT_TEST.$CODES.pth
$UMT_PATH/preprocess.py $FULL_VOCAB $SRC_VALID.$CODES
$UMT_PATH/preprocess.py $FULL_VOCAB $TGT_VALID.$CODES
$UMT_PATH/preprocess.py $FULL_VOCAB $SRC_TEST.$CODES
$UMT_PATH/preprocess.py $FULL_VOCAB $TGT_TEST.$CODES



#
# Summary
#
echo ""
echo "===== Data summary"
echo "Monolingual training data:"
echo "    EN: $SRC_TOK.$CODES.pth"
echo "    ZU: $TGT_TOK.$CODES.pth"
echo "Parallel validation data:"
echo "    EN: $SRC_VALID.$CODES.pth"
echo "    ZU: $TGT_VALID.$CODES.pth"
echo "Parallel test data:"
echo "    EN: $SRC_TEST.$CODES.pth"
echo "    ZU: $TGT_TEST.$CODES.pth"
echo ""

#
# Train fastText on concatenated embeddings
#

if ! [[ -f "$CONCAT_BPE" ]]; then
  echo "Concatenating source and target monolingual data..."
  cat $SRC_TOK.$CODES $TGT_TOK.$CODES | shuf > $CONCAT_BPE
fi
echo "Concatenated data in: $CONCAT_BPE"

if ! [[ -f "$CONCAT_BPE.vec" ]]; then
  echo "Training fastText on $CONCAT_BPE..."
  $FASTTEXT skipgram -epoch $N_EPOCHS -minCount 0 -dim 512 -thread $N_THREADS -ws 5 -neg 10 -input $CONCAT_BPE -output $CONCAT_BPE
fi
echo "Cross-lingual embeddings in: $CONCAT_BPE.vec"

