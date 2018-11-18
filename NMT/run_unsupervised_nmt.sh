#!/bin/bash
## With
MONO_DATASET='en:./data/mono/mono.en.tok.60000.pth,,;zu:./data/mono/mono.zu.tok.60000.pth,,'
PARA_DATASET='en-zu:,./data/para/enzu_parallel.dev.en.60000.pth,./data/para/enzu_parallel.dev.zu.60000.pth'
PRETRAINED='./data/mono/all.en-zu.60000.vec'

python main.py --exp_name enzu \
    --transformer True  --n_enc_layers 4 --n_dec_layers 4  \
    --share_enc 3  --share_dec 3  --share_lang_emb True  --share_output_emb True \
    --langs 'en,zu' --n_mono -1  --mono_dataset $MONO_DATASET  --para_dataset $PARA_DATASET \
    --mono_directions 'en,zu'  --word_shuffle 3 --word_dropout 0.1 --word_blank 0.2 \
    --pivo_directions 'en-zu-en,zu-en-zu' \
    --pretrained_emb $PRETRAINED  --pretrained_out True \
    --lambda_xe_mono '0:1,100000:0.1,300000:0' --lambda_xe_otfd 1 \
    --otf_num_processes 30   --otf_sync_params_every 1000 \
    --enc_optimizer adam,lr=0.0001 \
    --group_by_size True \
    --batch_size 32 \
    --epoch_size 500000 --stopping_criterion bleu_en_zu_valid,10 \
    --freeze_enc_emb False --freeze_dec_emb False                   


