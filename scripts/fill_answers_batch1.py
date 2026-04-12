#!/usr/bin/env python3
"""Batch 1: fill structured answers for sft-0001 to sft-0010."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ANSWERS: dict[str, str] = {
    "sft-0001": (
        "Conclusion: 一般建议宝宝大约在6个月时开始添加辅食；在4个月之后的体检时，可结合发育情况咨询医生是否适合开始。\n"
        "Evidence: 资料指出，6个月前建议仅接受母乳喂养，大约到6个月时可以开始添加辅食。资料同时说明，大多数孩子在4个月后挺舌反射会逐渐消失，开始喂辅食时应让孩子坐直、少量尝试；如果孩子拒绝，不要强迫，可以继续母乳或配方奶1到2周后再尝试。\n"
        "Citations: [2][3]\n"
        "Risk note: 添加辅食时应让宝宝坐直并使用小勺子；如果持续拒绝进食、吞咽异常或明显不适，应咨询医生。"
    ),
    "sft-0002": (
        "Conclusion: 没有证据表明辅食必须按固定顺序添加；传统上常从谷物开始，如果孩子主要吃母乳，富含铁和锌的婴儿肉类也很有价值。\n"
        "Evidence: 资料说明，传统建议先喂谷物，但没有医学证据证明特定顺序有特殊好处；先蔬菜还是先水果也没有明确证据支持。资料还提到，许多孩子会先接受婴儿麦片或米粉，而对主要母乳喂养的孩子，婴儿肉类因富含铁和锌也有帮助。每次最好只引入一种新食物，并观察3到5天。\n"
        "Citations: [1][2]\n"
        "Risk note: 引入新食物后如果出现腹泻、皮疹或呕吐，应停止该食物并咨询医生。"
    ),
    "sft-0003": (
        "Conclusion: 母乳喂养的宝宝通常需要从出生后不久开始补充维生素D；铁一般在出生后4到6个月内不需额外补充，但约6个月后应通过富含铁的辅食逐步补足。\n"
        "Evidence: 资料指出，母乳喂养婴儿需要补充维生素D，美国儿科学会建议从出生后不久开始每天补充400IU。关于铁，资料说明母乳喂养婴儿在出生后4到6个月通常不需要额外补铁，但随着生长加快，约6个月后应添加富含铁的辅食，如谷物、肉类和绿色蔬菜。若孕期有糖尿病、宝宝出生体重低或存在特殊健康问题，是否补铁需由医生判断。\n"
        "Citations: [1][2][3]\n"
        "Risk note: 不确定是否需要补充维生素D或铁时，应咨询儿科医生，不要自行长期补充。"
    ),
    "sft-0004": (
        "Conclusion: 配方奶喂养要重点注意正确姿势、奶瓶和奶嘴使用、喂奶节奏以及拍嗝和餐后护理。\n"
        "Evidence: 资料指出，喂奶时应半竖抱婴儿，不要平躺喂奶，以免增加窒息和中耳炎风险。奶液应没过瓶颈、充满奶嘴，以减少吞入空气；奶嘴孔大小应合适。资料还给出了常见喂食量和频率，并建议吃奶过程中每隔3到5分钟拍嗝一次，餐后竖抱20到30分钟，避免刚喂完就挤压腹部或剧烈玩耍。\n"
        "Citations: [1][3]\n"
        "Risk note: 如果宝宝喂养后频繁呛咳、明显不适或体重增长异常，应咨询医生。"
    ),
    "sft-0005": (
        "Conclusion: 拍嗝、打嗝和吐奶在婴儿期都较常见，通常与吃奶时吞入空气、吃得过多或打嗝和流口水有关；但反复剧烈呕吐需要警惕。\n"
        "Evidence: 资料说明，婴儿吃奶时常会吞入空气，尤其吃奶瓶时更常见，因此需要经常拍嗝。资料还指出，吐奶在婴儿中很普遍，常因吃得超过胃容量、打嗝或流口水引发，通常不会造成严重危险，随着月龄增长往往会好转。另一方面，真正的呕吐反应更剧烈；如果反复发生、喷射明显，或伴随异常颜色或血样物质，则需要重视。\n"
        "Citations: [1][2][3]\n"
        "Risk note: 如果出现频繁呕吐、黄绿色或血样呕吐物，或2周到4个月间持续喷射性呕吐，应及时就医。"
    ),
    "sft-0006": (
        "Conclusion: 新生儿出生后的最初几天，家长应重点观察黄疸、听力反应、皮肤状态、呼吸情况和体温监测方法，并及时和儿科医生沟通问题。\n"
        "Evidence: 资料提到，家长要留意黄疸是否持续或加重，注意孩子对声音是否有正常反应，以及皮肤松弛是否异常。资料还说明，新生儿头几天每分钟40到60次、短促浅表的呼吸通常可以是正常表现。除此之外，家长应提前了解正确测量体温的方法，并利用早期儿科随访及时提出喂养和护理方面的问题。\n"
        "Citations: [1][2][3]\n"
        "Risk note: 如果黄疸持续不退或加重、对声音反应异常、皮肤异常松弛，或出现明显呼吸困难，应尽快联系医生。"
    ),
    "sft-0007": (
        "Conclusion: 新生儿早期体格检查通常围绕整体健康状态、从头到脚的身体检查，以及后续随访中对发育和喂养情况的评估。\n"
        "Evidence: 资料指出，新生儿会在出生24小时内接受第一次彻底体格检查，出院前通常还会再次详细检查；如果出院较早，需要在出院后24到48小时随访。随访会评估体重变化、大小便、睡眠习性、喂养技巧及黄疸情况。医生还会从头到脚检查身体部位，包括臀部等，并在后续体检中关注神经反射、肌张力和整体发育情况。\n"
        "Citations: [1][2][3]\n"
        "Risk note: 如果早期检查提示异常，或家长对喂养、黄疸、活动或发育有担忧，应尽早复诊，不要等到问题明显加重。"
    ),
    "sft-0008": (
        "Conclusion: 第1个月宝宝的典型表现包括体重先降后回升、清醒时间逐渐变长、对外界反应增加，以及动作和互动能力开始变得更协调。\n"
        "Evidence: 资料指出，大多数婴儿在出生后5日内体重可下降约10%，通常到第10天恢复到出生体重。满月后，宝宝每天清醒时间会变长，对外界反应更多；他会更常聆听大人说话、盯着人看，偶尔通过扭动身体作出回应，同时把手送到嘴边等动作会更常见。资料也提到，不同宝宝在睡眠和性格上会有个体差异。\n"
        "Citations: [2][3]\n"
        "Risk note: 如果体重长期没有恢复、反应明显异常，或家长对吃奶、睡眠和活动情况有担忧，应咨询儿科医生。"
    ),
    "sft-0009": (
        "Conclusion: 1到3个月宝宝的免疫接种安排应按儿科医生建议和接种计划及时进行；如果漏种或时间有变化，需要尽快和医生沟通补种安排。\n"
        "Evidence: 当前检索到的资料并没有完整展开1到3个月阶段的详细疫苗清单，但明确提到，孩子的免疫接种应保持及时更新；如果漏掉了原定接种，医生会建议及时补种。资料还提示，很多关键疫苗需要在婴幼儿早期逐步完成，因此家长应持续和儿科医生确认时间表。\n"
        "Citations: [1]\n"
        "Risk note: 这组资料不足以单独给出完整的1到3个月疫苗明细；不要自行推断接种顺序，具体应以儿科医生和正式接种计划为准。"
    ),
    "sft-0010": (
        "Conclusion: 4到7个月宝宝常见的行为发展表现包括更主动地关注外界、喜欢触摸和探索、通过声音或动作寻求帮助，以及天生性格特征在这一阶段变得更明显。\n"
        "Evidence: 资料指出，4到7个月时婴儿会从相对被动逐渐变得更主动，学会坐直、用手和移动后，会更想接触周围事物；当自己做不到时，常会用尖叫、敲打或丢东西等方式吸引大人注意。资料同时说明，孩子急躁还是温顺、外向还是容易生气等性格特点会在这一阶段表现得更明显。\n"
        "Citations: [1]\n"
        "Risk note: 如果宝宝长期对外界刺激反应很弱、明显缺乏互动，或家长对行为发育有担忧，应咨询医生进一步评估。"
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fill batch 1 structured answers into a new annotation file.")
    parser.add_argument(
        "--input",
        default="data/sft_annotations.todo.jsonl",
        help="Source annotation file.",
    )
    parser.add_argument(
        "--output",
        default="data/sft_annotations.batch1.jsonl",
        help="Destination annotation file.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    records = [json.loads(line) for line in input_path.read_text(encoding="utf-8").splitlines() if line.strip()]

    updated_count = 0
    for record in records:
        sample_id = record.get("sample_id")
        if sample_id in ANSWERS:
            record["answer"] = ANSWERS[sample_id]
            updated_count += 1
            print(f"OK {sample_id}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        "\n".join(json.dumps(record, ensure_ascii=False) for record in records) + "\n",
        encoding="utf-8",
    )

    print(f"Output written to: {output_path}")
    print(f"Updated samples: {updated_count}")


if __name__ == "__main__":
    main()
