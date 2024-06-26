export CUDA_VISIBLE_DEVICES=0,1,2,3
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

DATASET_BASE_PATH="checkpoints/dataset"
LLAMA_BASE_PATH="meta-llama"
BASE_SAVE_PATH="checkpoints/deferral_finetuned"

DATASET_NAME="gsm8k-completion/Llama-2-70b-hf"
DEFERRAL_INIT_DATASET="gsm8k-completion/init-a-Llama-2-7b-hf+Llama-2-70b-hf"
MODEL_NAME="Llama-2-7b-hf"
NUM_GPUS=4
BATCH_SIZE_PER_GPU=2
TOTAL_BATCH_SIZE=128
GRADIENT_ACC_STEPS=$(($TOTAL_BATCH_SIZE/$NUM_GPUS/$BATCH_SIZE_PER_GPU))
echo "Training llama model ${MODEL_NAME} using $NUM_GPUS GPUs, $BATCH_SIZE_PER_GPU batch size per GPU, $GRADIENT_ACC_STEPS gradient accumulation steps"


export WANDB_PROJECT="deferral_finetune-${DATASET_NAME//\//_}-${MODEL_NAME}-$(date +'%y-%m-%d-%H-%M')"
# It will run two times, one for searching the gperp and one for real training 
python collm/training/deferral_trainer_hf.py \
    --model_name_or_path ${LLAMA_BASE_PATH}/${MODEL_NAME} \
    --tokenizer_name ${LLAMA_BASE_PATH}/${MODEL_NAME} \
    --use_fast_tokenizer False \
    --dataset_name ${DATASET_BASE_PATH}/${DEFERRAL_INIT_DATASET} \
    --deferral_initialization_weight_balance 8 \
    --deferral_initialization_search_version "v1" \
    --max_seq_length 2048 \
    --use_flash_attn \
    --deferral_initialization_search_max_steps 8000 \
    --do_train \
    --per_device_train_batch_size $BATCH_SIZE_PER_GPU \
    --gradient_accumulation_steps $GRADIENT_ACC_STEPS \
    --learning_rate 2e-5 \
    --lr_scheduler_type linear \
    --torch_dtype "bfloat16" \
    --warmup_ratio 0.04 \
    --weight_decay 0. \
    --evaluation_strategy "no" \
    --logging_steps 1 \
    --save_strategy epoch \
    --save_total_limit 1 \
    --num_train_epochs 2 \
    --output_dir ${BASE_SAVE_PATH}/${DATASET_NAME//\//_}/${MODEL_NAME}~${TOTAL_BATCH_SIZE}bz \
    --bf16 \
    --tf32 True \
    --report_to "wandb" \
    --log_level "info" 


deepspeed --master_port 29600 --include=localhost:0,1,2,3 collm/training/deferral_trainer_hf.py \
    --deepspeed ds_configs/stage2_no_offloading.conf \
    --model_name_or_path ${LLAMA_BASE_PATH}/${MODEL_NAME} \
    --tokenizer_name ${LLAMA_BASE_PATH}/${MODEL_NAME} \
    --use_flash_attn True \
    --use_fast_tokenizer False \
    --dataset_name ${DATASET_BASE_PATH}/${DATASET_NAME} \
    --deferral_initialization_search_max_steps 8000 \
    --deferral_trainer_version "v1" \
    --max_seq_length 2048 \
    --preprocessing_num_workers 64 \
    --do_train \
    --per_device_train_batch_size $BATCH_SIZE_PER_GPU \
    --gradient_accumulation_steps $GRADIENT_ACC_STEPS \
    --learning_rate 2e-5 \
    --lr_scheduler_type linear \
    --warmup_ratio 0.04 \
    --weight_decay 0. \
    --evaluation_strategy "no" \
    --logging_steps 1 \
    --save_strategy epoch \
    --save_total_limit 1 \
    --num_train_epochs 2 \
    --output_dir ${BASE_SAVE_PATH}/${DATASET_NAME//\//_}/${MODEL_NAME}~${TOTAL_BATCH_SIZE}bz \
    --bf16 \
    --tf32 True \
    --torch_dtype bfloat16 \
    --overwrite_output_dir \
    --report_to "wandb" \
    --log_level "info" 