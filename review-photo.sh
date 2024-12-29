#!/usr/bin/env bash

##############################################################################
# 0) 카메라 파일 목록을 가져와 파싱하기
##############################################################################
# - 각 줄에 대해:
#     #<번호> <파일이름> ... (중간 정보) ... <에포크타임?>
#   형태를 가정하여 정규식으로 추출
# - 날짜 정보(마지막 필드)가 에포크(숫자)라면, date 명령으로 변환하여 저장
##############################################################################

# gphoto2 출력 전체를 배열에 담기
mapfile -t RAW_LINES < <(gphoto2 --list-files)

# 배열: 파일번호 목록
declare -a FILE_NUMS
# 배열: 파일명 목록
declare -a FILE_NAMES
# 배열: 날짜/시간 문자열(옵션)
declare -a FILE_DATES

for line in "${RAW_LINES[@]}"; do
  # #1 DSCF0001.JPG rd 2456 KB 3120x2080 image/jpeg 1735438826
  # 정규식 캡처 그룹 (bash =~):
  #   1) 파일번호
  #   2) 파일이름
  #   3) (중간 정보들)
  #   4) 마지막 필드(숫자) → 에포크 타임 가정
  if [[ $line =~ ^#([0-9]+)[[:space:]]+([^[:space:]]+).*[[:space:]]([0-9]{9,})$ ]]; then
    file_num="${BASH_REMATCH[1]}"
    file_name="${BASH_REMATCH[2]}"
    epoch_val="${BASH_REMATCH[3]}"

    # 날짜 변환 시도 (macOS: date -r / Linux: date -d @...)
    # 여기서는 macOS 기준(-r) 예시, 필요 시 수정
    if date_string=$(date -r "$epoch_val" "+%Y-%m-%d %H:%M:%S" 2>/dev/null); then
      :
    else
      # 만약 변환 실패하면 그냥 숫자 그대로 쓴다.
      date_string="$epoch_val"
    fi

    FILE_NUMS+=( "$file_num" )
    FILE_NAMES+=( "$file_name" )
    FILE_DATES+=( "$date_string" )
  fi
done

##############################################################################
# 1) "몇 번 파일부터 시작?" 입력받기
##############################################################################
read -p "Enter the file number to start from: " START_NUM

# 파일번호 배열에서 START_NUM 위치 찾기
# (직접 index를 찾아야 함)
start_index=0
found_start_index=false

for i in "${!FILE_NUMS[@]}"; do
  if [[ "${FILE_NUMS[$i]}" -eq "$START_NUM" ]]; then
    start_index="$i"
    found_start_index=true
    break
  fi
done

if [ "$found_start_index" = false ]; then
  echo "File number $START_NUM not found in the current list. Exiting."
  exit 1
fi

##############################################################################
# 2) 리뷰 루프: n(다음), p(이전), k(keep), q(종료)
##############################################################################
current_index="$start_index"
total_count="${#FILE_NUMS[@]}"

# 임시 다운로드 경로
TMP_FILE="/tmp/gphoto2_review_temp.jpg"

while true; do
  # 범위 초과 시 종료 처리
  if [ "$current_index" -lt 0 ] || [ "$current_index" -ge "$total_count" ]; then
    echo "No more files to show (index out of range). Exiting."
    break
  fi

  file_num="${FILE_NUMS[$current_index]}"
  file_name="${FILE_NAMES[$current_index]}"
  file_date="${FILE_DATES[$current_index]}"


  # gphoto2로 임시 다운로드
  gphoto2 --get-file "$file_num" --force-overwrite --filename "$TMP_FILE" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Failed to download file #$file_num. Maybe it's missing or invalid?"
  else
    # kitty icat 미리보기 (kitty 터미널 환경이어야 함)
    kitty +kitten icat "$TMP_FILE"
  fi

  echo "---------------------------------------------------------"
  echo "Reviewing file #$file_num : $file_name"
  echo "Date : $file_date"
  echo "Index: $current_index/$((total_count-1))"
  echo "---------------------------------------------------------"

  echo -n "[n]ext / [p]rev / [k]eep / [q]uit? "
  read -n 1 answer
  echo

  case "$answer" in
    [nN])
      # 다음
      ((current_index++))
      ;;
    [pP])
      # 이전
      ((current_index--))
      ;;
    [kK])
      # keep → 현재 디렉토리에 저장
      #   파일번호 or 원본 파일명 사용 (원하시는 대로)
      #   예: "DSCF0001.JPG" 그대로 쓰거나, "photo-<번호>.jpg"로도 가능
      keep_name="$file_name"

      # 혹시 같은 이름이 이미 존재하면 덮어씌우는지 확인(여기선 덮어쓰기)
      gphoto2 --get-file "$file_num" --force-overwrite --filename "./$keep_name"
      echo "Saved file #$file_num as '$keep_name' in current directory."
      ;;
    [qQ])
      # 종료
      echo "Quitting."
      break
      ;;
    *)
      # 그 외 입력 → 그냥 무시
      echo "Skipping."
      ;;
  esac
done

echo "Done."
