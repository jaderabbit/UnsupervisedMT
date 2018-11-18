#!/bin/bash
## With
#usage: run_unsupervised_nmt.sh 
TARGET=$1
MONO_DATASET=en:./data/mono/mono.en.tok.60000.pth,,;$TARGET:./data/mono/mono.$TARGET.tok.60000.pth,,
PARA_DATASET=en-$TARGET:,./data/para/en$TARGET_parallel.dev.en.60000.pth,./data/para/en$TARGET_parallel.dev.$TARGET.60000.pth
PRETRAINED=./data/mono/all.en-$TARGET.60000.vec

echo ""
echo "===== Input parameters ====="
echo " TARGET       : $TARGET"
echo " MONO_DATASET : $MONO_DATASET"
echo " PARA_DATASET : $PARA_DATASET"
echo " PRETRAINED   : $PRETRAINED"
echo " "
python main.py --exp_name en$TARGET \
    --transformer True  --n_enc_layers 4 --n_dec_layers 4  \
    --share_enc 3  --share_dec 3  --share_lang_emb True  --share_output_emb True \
    --langs 'en,$TARGET' --n_mono -1  --mono_dataset $MONO_DATASET  --para_dataset $PARA_DATASET \
    --mono_directions 'en,$TARGET'  --word_shuffle 3 --word_dropout 0.1 --word_blank 0.2 \
    --pivo_directions 'en-$TARGET-en,$TARGET-en-$TARGET' \
    --pretrained_emb $PRETRAINED  --pretrained_out True \
    --lambda_xe_mono '0:1,100000:0.1,300000:0' --lambda_xe_otfd 1 \
    --otf_num_processes 30   --otf_sync_params_every 1000 \
    --enc_optimizer adam,lr=0.0001 \
    --group_by_size True \
    --batch_size 32 \
    --epoch_size 500000 --stopping_criterion bleu_en_$TARGET_valid,10 \
    --freeze_enc_emb False --freeze_dec_emb False                   


